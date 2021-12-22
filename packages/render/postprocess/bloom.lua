local ecs   = ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings".setting

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"

local bloom_chain_count<const> = 4
local bloom_ds_viewid<const> = viewidmgr.get "bloom_ds"
viewidmgr.check_range("bloom_ds", bloom_chain_count)

local bloom_us_viewid<const> = viewidmgr.get "bloom_us"
viewidmgr.check_range("bloom_us", bloom_chain_count)

for i=1, bloom_chain_count do
    w:register{name="bloom_downsample"..i}
    w:register{name="bloom_upsample"..i}
end

-- we write bloom downsample&upsample result to rt mipmap level
local mq_rt_mb = world:sub{"view_rect_changed", "main_queue"}

local bloom_sys = ecs.system "bloom_system"

local ds_drawer, us_drawer

function bloom_sys:init()
    local function create_sample_drawer(name, material)
        return ecs.create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                name = name,
                simplemesh = imesh.init_mesh(ientity.fullquad_mesh()),
                material = material,
                filter_state = "",
                scene = {srt={}},
                reference = true,
            }
        }
    end
    ds_drawer = create_sample_drawer("ds_drawer", "/pkg/ant.resources/materials/postprocess/downsample.material")
    us_drawer = create_sample_drawer("us_drawer", "/pkg/ant.resources/materials/postprocess/upsample.material")
end

local function downscale_bloom_vr(vr)
    return {
        x=0, y=0,
        w=math.max(1, vr.w//2), h=math.max(1, vr.h//2)
    }
end

local function upscale_bloom_vr(vr)
    return {
        x=0, y=0,
        w=vr.w*2, h=vr.h*2
    }
end

local function create_queue(viewid, vr, fbidx, queuename)
    ecs.create_entity{
        policy = {
            "ant.render|postprocess_queue",
            "ant.general|name",
        },
        data = {
            render_target = {
                view_rect = vr,
                view_mode = "",
                clear_state = {clear=""},
                viewid = viewid,
                fb_idx = fbidx,
            },
            [queuename] = true,
            queue_name = queuename,
            reference = true,
            name = queuename,
            bloom_queue = true,
        }
    }
end

local bloom_rb_flags = sampler.sampler_flag {
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
    for i=0, bloom_chain_count do
        fbs[#fbs+1] = fbmgr.create{
            rbidx = rbidx,
            mip=0,
        }
    end
    return fbs
end

local function init_drawer(drawer, handle)
    w:sync("render_object:in", drawer)
    local ro = drawer.render_object
    local ppi0 = ro.properties["s_postprocess_input0"]
    ppi0.set = imaterial.property_set_func "i"
    local v = ppi0.value
    v.texture = nil
    v.stage = 0
    v.handle = handle
    v.access = "r"
    v.mip = 0
end

local function recreate_chain_sample_queue(mqvr)
    local chain_vr = mqvr
    local rbidx = create_bloom_rb(mqvr)
    local fbpyramids = create_fb_pyramids(rbidx)
    assert(#fbpyramids == bloom_chain_count+1)
    --downsample
    local ds_viewid = bloom_ds_viewid
    for i=1, bloom_chain_count do
        chain_vr = downscale_bloom_vr(chain_vr)
        create_queue(ds_viewid, chain_vr, fbpyramids[i+1], "bloom_downsample"..i)
        ds_viewid = ds_viewid+1
    end

    --upsample
    local us_viewid = bloom_us_viewid
    for i=1, bloom_chain_count do
        chain_vr = upscale_bloom_vr(chain_vr)
        create_queue(us_viewid, chain_vr, fbpyramids[bloom_chain_count-i+1], "bloom_upsample"..i)
        us_viewid = us_viewid+1
    end

    local rbhandle = fbmgr.get_rb(rbidx).handle
    init_drawer(ds_drawer, rbhandle)
    init_drawer(us_drawer, rbhandle)
end

local function remove_sample_queues()
    local removed_fb_idx
    for e in w:select "bloom_queue render_target:in" do
        if removed_fb_idx == nil then
            fbmgr.destroy(e.render_target.fb_idx)
            removed_fb_idx = true
        end
        w:remove(e)
    end
end

function bloom_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local mqvr = mq.render_target.view_rect
    recreate_chain_sample_queue(mqvr)
end

local function check_need_recreate(vr)
    local q = w:singleton("bloom_upsample" .. bloom_chain_count, "render_target:in")
    local qvr = q.render_target.view_rect
    return qvr.w ~= vr.w or qvr.h ~= vr.h
end

function bloom_sys:data_changed()
    for msg in mq_rt_mb:each() do
        local vr = msg[3]
        if check_need_recreate(vr) then
            remove_sample_queues()
            recreate_chain_sample_queue(vr)
        end
    end
end

local function get_rt_handle(qn)
    local q = w:singleton(qn, "render_target:in")
    local rt = q.render_target
    return fbmgr.get_rb(rt.fb_idx, 1).handle
end

local function do_bloom_sample(start_viewid, drawer, ppi_handle, tagname, next_mip)
    w:sync("render_object:in", drawer)
    local ro = drawer.render_object

    for viewid=start_viewid, bloom_chain_count do
        local ppi0 = ro.properties["s_postprocess_input0"].value
        ppi0.handle = ppi_handle
        ppi0.mip = next_mip()
        irender.draw(viewid, ro)

        local qtag = tagname..(viewid-start_viewid+1)
        ppi_handle = get_rt_handle(qtag)
    end
end

function bloom_sys:bloom()
    --we just sample result to bloom buffer, and map bloom buffer from tonemapping stage
    local mip = 0

    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi_handle = pp.postprocess_input[1].handle
    do_bloom_sample(bloom_ds_viewid, ds_drawer, ppi_handle, "bloom_downsample", function () 
        mip = mip+1
        return mip
    end)

    do_bloom_sample(bloom_us_viewid, us_drawer, ppi_handle, "bloom_upsample", function ()
        mip = mip - 1
        return mip
    end)

    assert(mip == 0, "upsample result should write to top mipmap")
end
