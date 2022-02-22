local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"

local setting   = import_package "ant.settings".setting
local enable_bloom = setting:get "graphic/postprocess/bloom/enable"

local bloom_ds_viewid<const>, bloom_chain_count<const> = viewidmgr.get_range "bloom_ds"
local bloom_us_viewid<const>, bloom_chain_count2<const> = viewidmgr.get_range "bloom_us"
assert(bloom_chain_count == bloom_chain_count2)

for i=1, bloom_chain_count do
    w:register{name="bloom_downsample"..i}
    w:register{name="bloom_upsample"..i}
end

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

local function remove_all_bloom_queue()
    for e in w:select "bloom_queue" do
        w:remove(e)
    end
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
            mip=i,
            resolve="",
        }
    end
    return fbs
end

local function check_size_valid(mqvr)
    local s = math.max(mqvr.w, mqvr.h)
    local c = math.log(s, 2)
    return c >= bloom_chain_count
end

local function create_chain_sample_queue(mqvr)
    if not check_size_valid(mqvr) then
        log.warn(("main queue buffer, w:%d, h:%d, in not valid for bloom, need chain: %d"):format(mqvr.w, mqvr.h, bloom_chain_count))
        return
    end
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

    local pp = w:singleton("postprocess", "postprocess_input:in")
    local bloom_color_handle = fbmgr.get_rb(rbidx).handle
    pp.postprocess_input.bloom_color_handle = bloom_color_handle
end

function bloom_sys:init_world()
    if not enable_bloom then
        return 
    end
    local mq = w:singleton("main_queue", "render_target:in")
    local mqvr = mq.render_target.view_rect
    create_chain_sample_queue(mqvr)
end

local mqvr_mb = world:sub{"viewrect_changed", "main_queue"}
function bloom_sys:data_changed()
    if not enable_bloom then
        return 
    end

    for msg in mqvr_mb:each() do
        local mqvr = msg[3]
        local q = w:singleton("bloom_upsample"..bloom_chain_count, "render_target:in")
        if q then
            local vr = q.render_target.view_rect
            if mqvr.w ~= vr.w or mqvr.h ~= vr.h then
                remove_all_bloom_queue()
            end
        else
            create_chain_sample_queue(mqvr)
        end
    end
end

function bloom_sys:entity_remove()
    if not enable_bloom then
        return 
    end

    local fbidx
    for e in w:select "REMOVED bloom_queue render_target:in" do
        if fbidx == nil then
            fbmgr.destroy(fbidx)
            fbidx = e.render_target.fb_idx
        end
    end

    if fbidx then
        fbidx = nil
        local mq = w:singleton("main_queue", "render_target:in")
        create_chain_sample_queue(mq.render_target.view_rect)
    end
end

local scenecolor_property = {
    stage = 0,
    mip = 0,
    access = "r",
    image = {handle=nil}
}

local function do_bloom_sample(viewid, drawer, ppi_handle, next_mip)
    w:sync("render_object:in", drawer)
    local ro = drawer.render_object

    local rbhandle = fbmgr.get_rb(fbmgr.get_byviewid(viewid)[1].rbidx).handle
    for i=1, bloom_chain_count do
        local mip = next_mip()
        scenecolor_property.image.handle = ppi_handle
        scenecolor_property.mip = mip

        imaterial.set_property_directly(ro.properties, "s_scene_color", scenecolor_property)

        local bloom_param = ro.properties["u_bloom_param"].value
        bloom_param.v = math3d.set_index(bloom_param, 1, mip)
        irender.draw(viewid, ro)
        ppi_handle = rbhandle
        viewid = viewid + 1
    end

    return ppi_handle
end

function bloom_sys:bloom()
    if not enable_bloom or w:singleton("bloom_queue", "render_target:in") == nil then
        return
    end

    --we just sample result to bloom buffer, and map bloom buffer from tonemapping stage
    local mip = 0

    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi_handle = pp.postprocess_input.scene_color_handle
    ppi_handle = do_bloom_sample(bloom_ds_viewid, ds_drawer, ppi_handle, function () 
        local m = mip
        mip = m+1
        return m
    end)

    do_bloom_sample(bloom_us_viewid, us_drawer, ppi_handle, function ()
        local m = mip
        mip = m-1
        return m
    end)

    assert(mip == 0, "upsample result should write to top mipmap")
end
