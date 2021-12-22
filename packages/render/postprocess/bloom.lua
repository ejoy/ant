local ecs   = ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings".setting

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local imesh     = ecs.import.interface "ant.asset|imesh"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"

local bloom_chain_count<const> = 4
local bloom_ds_viewid<const> = viewidmgr.get "bloom_ds"
viewidmgr.check_range("bloom_ds", bloom_chain_count)

local bloom_us_viewid<const> = viewidmgr.get "bloom_us"
viewidmgr.check_range("bloom_us", bloom_chain_count)

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
    w:register{name=queuename}
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
    for i=1, bloom_chain_count do
        fbs[#fbs+1] = fbmgr.create{
            rbidx = rbidx,
            mip=i,
        }
    end
    return fbs
end

local function recreate_chain_sample_queue(mqvr)
    local chain_vr = downscale_bloom_vr(mqvr)
    local rb = create_bloom_rb(chain_vr)

    local fbpyramids = create_fb_pyramids(rb)

    --downsample
    local ds_viewid = bloom_ds_viewid
    for i=1, bloom_chain_count do
        create_queue(chain_vr, ds_viewid, fbpyramids[i], "bloom_downsample"..i)
        chain_vr = downscale_bloom_vr(chain_vr)
        ds_viewid = ds_viewid+i
    end

    chain_vr = upscale_bloom_vr(chain_vr)

    --upsample
    local us_viewid = bloom_us_viewid
    for i=1, bloom_chain_count do
        chain_vr = upscale_bloom_vr(chain_vr)
        create_queue(us_viewid, chain_vr, fbpyramids[bloom_chain_count-i+1], "bloom_upsample"..i)
        us_viewid = us_viewid+1
    end
end

local function remove_sample_queues()
    for e in w:select "bloom_queue" do
        w:remove(e)
    end
end

function bloom_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local mqvr = mq.render_target.view_rect
    recreate_chain_sample_queue(mqvr)
end

function bloom_sys:data_changed()
    for msg in mq_rt_mb:each() do
        remove_sample_queues()
        recreate_chain_sample_queue(msg[3])
    end
end

function bloom_sys:bloom()
    --we just sample result to bloom buffer, and map bloom buffer from tonemapping stage
    local function draw(sample_viewid, drawer)
        w:sync("render_object:in", drawer)
        local ro = ds_drawer.render_object
        for viewid=sample_viewid, bloom_chain_count do
            irender.draw(viewid, ro)
        end
    end

    draw(bloom_ds_viewid, ds_drawer)
    draw(bloom_us_viewid, us_drawer)
end
