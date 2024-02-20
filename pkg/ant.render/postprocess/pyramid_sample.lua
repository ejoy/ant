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
local irender   = ecs.require "ant.render|render"
local queuemgr  = ecs.require "queue_mgr"
local util      = ecs.require "postprocess.util"

local ips = {}

local RB_FLAGS<const> = sampler {
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE"
}

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

local function create_fb_pyramids(rbidx, count)
    local fbs = {}
    for i=0, count do
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

function ips.init_sample(count, basename, baseviewid)
    local s = {}
    for i=1, count do
        s[i] = {
            viewid = baseviewid+i-1,
            queue_name = basename .. i,
        }
    end

    return s
end

local function create_sample_queues(e, mqvr)
    local ps = e.pyramid_sample
    local downsample, upsample = ps.downsample, ps.upsample

    assert(#downsample == #upsample)
    local mipcount<const> = #downsample

    local chain_vr = {[1] = mqvr}

    local rbidx = create_rb(mqvr)
    local fbpyramids = create_fb_pyramids(rbidx, mipcount)

    local function init_sample(s, vr, fb)
        local qn = s.queue_name
        local _ = queuemgr.has(qn) or error(("%s: queue_name is not register"):format(qn))
        s.queueeid = util.create_queue(s.viewid, vr, fb, qn, nil, true) -- 2 3 4 5 
        s.render_arg = irender.pack_render_arg(qn, s.viewid)
    end
    --downsample
    for idx, ds in ipairs(downsample) do
        init_sample(ds, downscale_vr(chain_vr), fbpyramids[idx+1])
    end

    --upsample
    for idx, us in ipairs(upsample) do
        init_sample(us, chain_vr[mipcount-idx+1], fbpyramids[mipcount-idx+1])
    end
end

local SCENE_COLOR_PROPERTY = {
    stage   = 0,
    mip     = 0,
    access  = "r",
    type    = 'i',
    value   = nil,
}

local function create_drawers(e)
    local ps = e.pyramid_sample
    local ds, us = ps.downsample, ps.upsample
    assert(#ds == #us)
    local mipcount<const> = #ds
    for i=1, mipcount do
        ds[i].drawer = world:create_entity{
            policy = {"ant.render|simplerender",},
            data = {
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/downsample.material",
                visible_state     = "",
                scene             = {},
            }
        }
        us[i].drawer = world:create_entity{
            policy = {"ant.render|simplerender",},
            data = {
                simplemesh        = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/upsample.material",
                visible_state     = "",
                scene             = {},
            }
        }
    end
end

local function remove_sample_queues(ps)
    local ds, us = ps.downsample, ps.upsample
    local function remove_sample_entites(ss)
        for _, s in ipairs(ss) do
            w:remove(s.queueeid)
            --not remove drawereid
        end
    end

    remove_sample_entites(ds)
    remove_sample_entites(us)
end

local function last_queue_viewrect(ps)
    local lasteid = ps.upsample[#ps.upsample].queueeid
    local e = world:entity(lasteid, "render_target:in")
    if e then
        return e.render_target.viewrect
    end
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
function ps_sys:data_changed()
    for _,_, vp in vr_mb:unpack() do
        for e in w:select "pyramid_sample:in" do
            local ps = e.pyramid_sample
            local lq = last_queue_viewrect(ps)
            if lq then
                local vr = lq.render_target.view_rect
                if vp.w ~= vr.w or vp.h ~= vr.h then
                    remove_sample_queues(ps)
                    create_sample_queues(e, vp)
                end
            end
        end

        break   --do once
    end
end

function ips.update(e, mqvr)
    create_sample_queues(e, mqvr)
    create_drawers(e)
end

local function do_sample(sample_params, samplers, inputhandle, next_mip)
    for _, s in ipairs(samplers) do
        local fb = assert(fbmgr.get_byviewid(s.viewid))
        local outputhandle = fb[1].handle

        local drawer = world:entity(s.drawer, "filter_material:in")
        local fm = drawer.filter_material
        local mi = fm.DEFAULT_MATERIAL
        local mip = next_mip()
        sample_params[1] = mip

        SCENE_COLOR_PROPERTY.value, SCENE_COLOR_PROPERTY.mip = inputhandle, mip
        mi.s_scene_color = SCENE_COLOR_PROPERTY
        mi.u_bloom_param = sample_params
        inputhandle = outputhandle

        irender.draw(s.render_arg, s.drawer)
    end
    return inputhandle
end

function ips.do_pyramid_sample(e, input_handle)
    local ps = e.pyramid_sample
    local sample_params = ps.sample_params
    local mip = 0

    local current_handle = do_sample(sample_params, ps.downsample, input_handle, function () 
        local m = mip
        mip = m+1
        return m
    end)

    do_sample(sample_params, ps.upsample, current_handle, function ()
        local m = mip
        mip = m-1
        return m
    end)
end

return ips