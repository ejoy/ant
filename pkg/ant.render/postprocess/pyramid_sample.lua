local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local ps_sys = ecs.system "pyramid_sample_system"

if (not setting:get "graphic/postprocess/blur/enable") and (not setting:get "graphic/postprocess/bloom/enable") then
    return
end

local fbmgr     = require "framebuffer_mgr"
local sampler   = import_package "ant.render.core".sampler
local irender   = ecs.require "ant.render|render_system.render"

local util      = ecs.require "postprocess.util"

local ips = {}

local PYRAMID_MIPCOUNT <const> = 4

local RB_FLAGS = sampler {
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE"
}

local function create_pyramid_sample_queue(e, mqvr)

    local function create_rb(vr)
        return fbmgr.create_rb{
            w = vr.w,
            h = vr.h,
            format = "RGBA16F",
            layers=1,
            mipmap=true,
            flags = RB_FLAGS,
        }
    end

    local function create_fb_pyramids(rbidx)
        local fbs = {}
        for i=0, PYRAMID_MIPCOUNT do
            fbs[#fbs+1] = fbmgr.create{
                rbidx = rbidx,
                mip=i,
                resolve="",
            }
        end
        return fbs
    end

    local function downscale_vr(chain_vr)
        local vr = chain_vr[#chain_vr]
        chain_vr[#chain_vr+1] = {
            x=0, y=0,
            w=math.max(1, vr.w//2), h=math.max(1, vr.h//2)
        }
        return chain_vr[#chain_vr]
    end
    
    local ps = e.pyramid_sample
    local ds_viewid, us_viewid, ds_queue, us_queue, queue_name = ps.downsample_viewid, ps.upsample_viewid, ps.downsample_queue, ps.upsample_queue, ps.queue_name

    local chain_vr = {[1] = mqvr}

    local rbidx = create_rb(mqvr)
    local fbpyramids = create_fb_pyramids(rbidx)

    --downsample
    for i=1, PYRAMID_MIPCOUNT do
        local vr = downscale_vr(chain_vr)
        util.create_queue(ds_viewid, vr, fbpyramids[i+1], ds_queue..i, queue_name, true) -- 2 3 4 5 
        ds_viewid = ds_viewid + 1
    end

    --upsample
    for i=1, PYRAMID_MIPCOUNT do
        local vr = chain_vr[PYRAMID_MIPCOUNT-i+1]
        util.create_queue(us_viewid, vr, fbpyramids[PYRAMID_MIPCOUNT-i+1], us_queue..i, queue_name, true) -- 4 3 2 1
        us_viewid = us_viewid + 1
    end
    ps.scene_color_property = {
        stage   = 0,
        mip     = 0,
        access  = "r",
        value  = fbmgr.get_rb(rbidx).handle,
        type = 'i'
    }
end

local function create_pyramid_sample_drawer(e)
    local ps = e.pyramid_sample
    local ds_name, us_name = ps.downsample_queue, ps.upsample_queue
    local ds_drawers, us_drawers = {}, {}
    for i = 1, PYRAMID_MIPCOUNT do
        local ds_drawer = "downsample_drawer"..i
        local us_drawer = "upsample_drawer"..i
        local ds_queue  = ds_name..i
        local us_queue  = us_name..i
        ds_drawers[#ds_drawers+1] = world:create_entity{
            policy = {
                "ant.render|simplerender",
            },
            data = {
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/downsample.material",
                visible_state     = ds_queue,
                view_visible      = true,
                [ds_drawer]       = true,
                scene             = {},
            }
        }
        us_drawers[#us_drawers+1] = world:create_entity{
            policy = {
                "ant.render|simplerender",
            },
            data = {
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/upsample.material",
                visible_state     = us_queue,
                view_visible      = true,
                [us_drawer]       = true,
                scene             = {},
            }
        }
    end
    ps.downsample_drawers, ps.upsample_drawers = ds_drawers, us_drawers
end

function ps_sys:init()
    for i=1, PYRAMID_MIPCOUNT do
        local ds_drawer = "downsample_drawer"..i
        local us_drawer = "upsample_drawer"..i
        w:register{name = ds_drawer}
        w:register{name = us_drawer}
    end    
end

--[[ 
    pyramid_sample
	    downsample_queue (ex: "bloom_downsample")
	    upsample_queue (ex: "bloom_upsample")
	    downsample_viewid
	    upsample_viewid
	    downsample_drawer (drawer eid array)
	    upsample_drawer[] (drawer eid array)
	    queue_name (ex: "bloom_queue")
	    scene_color_property
	    sample_params 
]]

--[[ function ps_sys:entity_init()
    local mq = w:first("main_queue render_target:in")
    local mqvr = mq.render_target.view_rect
    for e in w:select "INIT pyramid_sample:update pyramid_sample_ready?out" do
        create_pyramid_sample_queue(e, mqvr)
        create_pyramid_sample_drawer(e)
        e.pyramid_sample_ready = true
    end
end ]]

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

function ps_sys:data_changed()

    local function remove_all_pyramid_sample_queue(queue_name)
        for e in w:select(queue_name) do
            w:remove(e)
        end
    end

    for _,_, vp in vr_mb:unpack() do
        for e in w:select "pyramid_sample:update" do
            local ps = e.pyramid_sample
            local last_queue_entity = w:first(("%s%d render_target:in"):format(ps.upsample_queue, PYRAMID_MIPCOUNT))
            if last_queue_entity then
                local vr = last_queue_entity.render_target.view_rect
                if vp.w ~= vr.w or vp.h ~= vr.h then
                    remove_all_pyramid_sample_queue(ps.queue_name) -- enter twice in same frame
                    create_pyramid_sample_queue(e, vp)
                    break
                end
            end
        end
    end
end

function ips.set_pyramid_sample_components(e, mqvr)
    create_pyramid_sample_queue(e, mqvr)
    create_pyramid_sample_drawer(e)
end

function ips.do_pyramid_sample(e, input_handle)

    local function do_sample(scene_color_property, sample_params, viewid, drawers, current_handle, next_mip)
        local fb = fbmgr.get_byviewid(viewid)
        if fb then
            local rbhandle = fbmgr.get_rb(fb[1].rbidx).handle
            for i=1, PYRAMID_MIPCOUNT do
                local drawer = world:entity(drawers[i], "filter_material:in")
                local fm = drawer.filter_material
                local material = fm.main_queue
                local mip = next_mip()
                sample_params[1] = mip
                scene_color_property.value = current_handle
                scene_color_property.mip = mip
                material.s_scene_color = scene_color_property
                material.u_bloom_param = sample_params
                current_handle = rbhandle 
            end
            return current_handle
        end
    end

    local ps = e.pyramid_sample
    local ds_viewid, us_viewid, ds_drawers, us_drawers = ps.downsample_viewid, ps.upsample_viewid, ps.downsample_drawers, ps.upsample_drawers
    local sample_params, scene_color_property = ps.sample_params, ps.scene_color_property
    local mip = 0

    local current_handle = input_handle
    current_handle = do_sample(scene_color_property, sample_params, ds_viewid, ds_drawers, current_handle, function () 
        local m = mip
        mip = m+1
        return m
    end)

    do_sample(scene_color_property, sample_params, us_viewid, us_drawers, current_handle, function ()
        local m = mip
        mip = m-1
        return m
    end)
end

function ips.get_pyramid_mipcount()
    return PYRAMID_MIPCOUNT
end

return ips