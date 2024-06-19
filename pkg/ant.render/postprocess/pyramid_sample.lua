local ecs   = ...
local world = ecs.world
local w     = world.w

local fbmgr     = require "framebuffer_mgr"
local sampler   = import_package "ant.render.core".sampler
local irender   = ecs.require "ant.render|render"
local queuemgr  = ecs.require "queue_mgr"
local util      = ecs.require "postprocess.util"

local ips = {}

local RB_FLAGS<const> = sampler {
    RT  ="RT_ON",
    MIN ="LINEAR",
    MAG ="LINEAR",
    U   ="CLAMP",
    V   ="CLAMP",
    BLIT="BLIT_COMPUTEWRITE"
}

local function create_rb(vr)
    return fbmgr.create_rb{
        w       = vr.w,
        h       = vr.h,
        format  = "RGBA16F",
        layers  = 1,
        mipmap  = true,
        flags   = RB_FLAGS,
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

local function create_sample_queues(ps, mqvr)
    local downsample, upsample = ps.downsample, ps.upsample

    assert(#downsample == #upsample)
    local mipcount<const> = #downsample

    local chain_vr = {[1] = mqvr}

    local rbidx = create_rb(mqvr)
    local fbpyramids = create_fb_pyramids(rbidx, mipcount)

    local function init_sample(s, vr, fb)
        local qn = s.queue_name
        local _ = queuemgr.has(qn) or error(("%s: queue_name is not register"):format(qn))
        s.queue = util.create_queue(s.viewid, vr, fb, qn)
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

local function create_drawers(ps)
    local ds, us = ps.downsample, ps.upsample
    assert(#ds == #us)
    local mipcount<const> = #ds
    for i=1, mipcount do
        local d, u = ds[i], us[i]
        d.drawer = world:create_entity{
            policy = {"ant.render|simplerender",},
            data = {
                mesh_result       = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/downsample.material",
                visible_masks     = "",
                scene             = {},
            }
        }
        d.mip = i-1

        u.drawer = world:create_entity{
            policy = {"ant.render|simplerender",},
            data = {
                mesh_result       = irender.full_quad(),
                material          = "/pkg/ant.resources/materials/postprocess/upsample.material",
                visible_masks     = "",
                scene             = {},
            }
        }
        u.mip = mipcount-1 - d.mip
    end
end

local function remove_sample_queues(ps)
    local ds, us = ps.downsample, ps.upsample
    local function remove_sample_entites(ss)
        for _, s in ipairs(ss) do
            w:remove(s.queue)
            --not remove drawereid
        end
    end

    remove_sample_entites(ds)
    remove_sample_entites(us)
end

local function last_queue_viewrect(ps)
    local lasteid = ps.upsample[#ps.upsample].queue
    local e = world:entity(lasteid, "render_target:in")
    if e then
        return e.render_target.viewrect
    end
end

function ips.update_viewrect(e, vp)
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

local function create_pyramid_sample(ps)
    return world:create_entity{
        policy = {
            "ant.render|pyramid_sample",
        },
        data = {
            bloom = true,
            pyramid_sample = ps,
        }
    }
end

function ips.create(pyramid_sample, mqvr)
    create_sample_queues(pyramid_sample, mqvr)
    create_drawers(pyramid_sample)
    return create_pyramid_sample(pyramid_sample)
end

function ips.update_smaple_handles(e, scene_color_handle)
    local function update_sample_handle(samples, inputhandle)
        for i=1, #samples do
            local d = samples[i]
            d.handle = inputhandle
    
            local fb = fbmgr.get_byviewid(d.viewid)
            inputhandle = fbmgr.get_rb(fb, 1).handle
        end

        return inputhandle
    end

    update_sample_handle(e.pyramid_sample.upsample, 
        update_sample_handle(e.pyramid_sample.downsample, scene_color_handle))
end

local function do_sample(samplers, param_modifier)
    for _, s in ipairs(samplers) do
        local drawer = world:entity(s.drawer, "filter_material:in")
        param_modifier:update(s, drawer.filter_material.DEFAULT_MATERIAL, s.mip)
        irender.draw(s.render_arg, s.drawer)
    end
end

function ips.do_pyramid_sample(e, param_modifier)
    local ps = e.pyramid_sample
    do_sample(ps.downsample,    param_modifier)
    do_sample(ps.upsample,      param_modifier)
end

return ips