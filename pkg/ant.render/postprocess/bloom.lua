local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local fbmgr     = require "framebuffer_mgr"
local sampler   = import_package "ant.general".sampler
local irender   = ecs.require "ant.render|render_system.render"
local util      = ecs.require "postprocess.util"
local renderutil= require "util"
local setting   = import_package "ant.settings".setting
local bloom_sys = ecs.system "bloom_system"
local bloom_setting = setting:data().graphic.postprocess.bloom
local ENABLE_BLOOM<const> = bloom_setting.enable

if not ENABLE_BLOOM then
    renderutil.default_system(bloom_sys, "init", "init_world", "data_changed", "bloom")
    return
end

local hwi       = import_package "ant.hwi"

local bloom_ds_viewid<const> = hwi.viewid_get "bloom_ds1"
local bloom_us_viewid<const> = hwi.viewid_get "bloom_us1"
local BLOOM_MIPCOUNT<const> = 4
local BLOOM_PARAM = math3d.ref(math3d.vector(0, bloom_setting.inv_highlight, bloom_setting.threshold, 0))


function bloom_sys:init()
    for i=1, BLOOM_MIPCOUNT do
        local ds_drawer = "downsample_drawer"..i
        local us_drawer = "upsample_drawer"..i
        local ds_queue  = "bloom_downsample"..i
        local us_queue  = "bloom_upsample"..i
        w:register{name = ds_queue}
        w:register{name = us_queue}
        w:register{name = ds_drawer}
        w:register{name = us_drawer}
        world:create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                name              = ds_drawer,
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/downsample.material",
                visible_state     = ds_queue,
                view_visible      = true,
                [ds_drawer]       = true,
                scene             = {},
            }
        }
        world:create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                name              = us_drawer,
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/upsample.material",
                visible_state     = us_queue,
                view_visible      = true,
                [us_drawer]       = true,
                scene             = {},
            }
        }
    end
    
end

local function downscale_bloom_vr(chain_vr)
    local vr = chain_vr[#chain_vr]
    chain_vr[#chain_vr+1] = {
        x=0, y=0,
        w=math.max(1, vr.w//2), h=math.max(1, vr.h//2)
    }
    return chain_vr[#chain_vr]
end

local function upscale_bloom_vr(vr)
    return {
        x=0, y=0,
        w=vr.w*2, h=vr.h*2
    }
end

local function remove_all_bloom_queue()
    for e in w:select "bloom_queue" do
        w:remove(e)
    end
end



local bloom_rb_flags = sampler {
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
}

local function create_bloom_rb(vr)
    return fbmgr.create_rb{
        w = vr.w,
        h = vr.h,
        format = "RGBA16F",
        layers=1,
        mipmap=true,
        flags = bloom_rb_flags,
    }
end

local function create_fb_pyramids(rbidx)
    local fbs = {}
    for i=0, BLOOM_MIPCOUNT do
        fbs[#fbs+1] = fbmgr.create{
            rbidx = rbidx,
            mip=i,
            resolve="",
        }
    end
    return fbs
end

local function check_size_valid(mqvr)
    local s = math.max(mqvr.w, mqvr.h)
    local c = math.log(s, 2)
    return c >= BLOOM_MIPCOUNT
end

local function create_chain_sample_queue(mqvr)
    if not check_size_valid(mqvr) then
        log.warn(("main queue buffer, w:%d, h:%d, in not valid for bloom, need chain: %d"):format(mqvr.w, mqvr.h, BLOOM_MIPCOUNT))
        return
    end
    local chain_vr = {[1] = mqvr}

    local rbidx = create_bloom_rb(mqvr)
    local fbpyramids = create_fb_pyramids(rbidx)
    assert(#fbpyramids == BLOOM_MIPCOUNT+1)
    --downsample
    local ds_viewid = bloom_ds_viewid
    for i=1, BLOOM_MIPCOUNT do
        local vr = downscale_bloom_vr(chain_vr)
        util.create_queue(ds_viewid, vr, fbpyramids[i+1], "bloom_downsample"..i, "bloom_queue") -- 2 3 4 5 
        ds_viewid = ds_viewid+1
    end

    --upsample
    local us_viewid = bloom_us_viewid
    for i=1, BLOOM_MIPCOUNT do
        local vr = chain_vr[BLOOM_MIPCOUNT-i+1]
        util.create_queue(us_viewid, vr, fbpyramids[BLOOM_MIPCOUNT-i+1], "bloom_upsample"..i, "bloom_queue") -- 4 3 2 1
        us_viewid = us_viewid+1
    end

    local pp = w:first("postprocess postprocess_input:in")
    local bloom_color_handle = fbmgr.get_rb(rbidx).handle
    pp.postprocess_input.bloom_color_handle = bloom_color_handle
end

function bloom_sys:init_world()
    local mq = w:first("main_queue render_target:in")
    local mqvr = mq.render_target.view_rect
    create_chain_sample_queue(mqvr)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

function bloom_sys:data_changed()
    for _,_, vp in vr_mb:unpack() do
        local q = w:first(("bloom_upsample%d render_target:in"):format(BLOOM_MIPCOUNT))
        if q then
            local bloom_vr = q.render_target.view_rect
            if vp.w ~= bloom_vr.w or vp.h ~= bloom_vr.h then
                remove_all_bloom_queue() -- enter twice in same frame
                create_chain_sample_queue(vp)
                break
            end
        end
    end
end


local scenecolor_property = {
    stage   = 0,
    mip     = 0,
    access  = "r",
    value  = nil,
    type = 'i'
}

local function do_bloom_sample(viewid, drawertag, ppi_handle, next_mip)
    local fb = fbmgr.get_byviewid(viewid)
    if fb then
        local rbhandle = fbmgr.get_rb(fb[1].rbidx).handle
        for i=1, BLOOM_MIPCOUNT do
            local drawer = w:first(drawertag .. i .. " filter_material:in")
            local fm = drawer.filter_material
            local material = fm.main_queue
            local mip = next_mip()
            BLOOM_PARAM[1] = mip
            scenecolor_property.value = ppi_handle
            scenecolor_property.mip = mip
            material.s_scene_color = scenecolor_property
            material.u_bloom_param = BLOOM_PARAM
            ppi_handle = rbhandle 
        end
    
        return ppi_handle
    end
end

function bloom_sys:bloom()
    --we just sample result to bloom buffer, and map bloom buffer from tonemapping stage
    local mip = 0

    local pp = w:first("postprocess postprocess_input:in")
    local ppi_handle = pp.postprocess_input.scene_color_handle
    ppi_handle = do_bloom_sample(bloom_ds_viewid, "downsample_drawer", ppi_handle, function () 
        local m = mip
        mip = m+1
        return m
    end)

    do_bloom_sample(bloom_us_viewid, "upsample_drawer", ppi_handle, function ()
        local m = mip
        mip = m-1
        return m
    end)

    assert(mip == 0, "upsample result should write to top mipmap")
end
