local ecs   = ...
local world = ecs.world
local w     = world.w

local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local samplerutil=require "sampler"

local bgfx      = require "bgfx"

local irender   = ecs.import.interface "ant.render|irender"

local resolve_msaa_sys = ecs.system "resolve_msaa_system"

local resolve_viewid = viewidmgr.get "resolve"

local rb_flag = samplerutil.sampler_flag {
	RT="RT_ON",
	MIN="LINEAR",
	MAG="LINEAR",
	U="CLAMP",
	V="CLAMP",
}

local function create_fb(mq_fb)
    local rbs = {}
    for i=1, #mq_fb do
        local rbidx = mq_fb[i]
        assert(irender.is_msaa_buffer(rbidx))
        local rb = fbmgr.get_rb(rbidx)
        rbs[#rbs+1] = {
            w = rb.w, h = rb.h,
            layers = rb.layers,
            format = rb.format,
            flags = rb_flag,
        }
    end

    rbs[1].mipmap = true

    local handles = {}
    for i=1, #rbs do
        handles[#handles+1] = fbmgr.create_rb(rbs[i])
    end

    return fbmgr.create(handles)
end

function resolve_msaa_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local vr = mq.render_target.view_rect

    ecs.create_entity{
        policy = {
            "ant.render|postprocess_queue",
            "ant.render|watch_screen_buffer",
            "ant.general|name",
        },
        data = {
            name = "resolver",
            render_target = {
                viewid = resolve_viewid,
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                view_mode = "",
                clear_state = {clear = ""},
                fb_idx = create_fb(fbmgr.get(mq.render_target.fb_idx))
            },
            watch_screen_buffer = true,
            resolver = true,
        }
    }

    --TODO: we just blit this buffer to resolve msaa, if we need sample this buffer to generate other info, like velocity buffer(for motion blur)

    local imesh = ecs.import.interface"ant.asset|imesh"
    local ientity = ecs.import.interface "ant.render|entity"
    w:register {name="copy_scene"}
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = imesh.init_mesh(ientity.quad_mesh{x=-1,y=-1, w=2, h=2}),
            material = "/pkg/ant.resources/materials/texquad.material",
            scene = {srt={}},
            state = "",
            name = "copy_scene",
            copy_scene = true
        }
    }
end

function resolve_msaa_sys:resolve()
    local pp = w:singleton("postprocess", "postprocess_input:in")
    local resolver = w:singleton("resolver", "render_target:in")
    local ppi = pp.postprocess_input
    local rt = resolver.render_target

    local tq = w:singleton("copy_scene", "render_object:in")
    local ro = tq.render_object
    local imaterial = ecs.import.interface "ant.asset|imaterial"
    imaterial.set_property_directly(ro.properties, "s_tex", {stage=0, texture={handle=ppi[1].handle}})
    irender.draw(rt.viewid, ro)
end