local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"

local tm_sys    = ecs.system "tonemapping_system"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh     = ecs.import.interface "ant.asset|imesh"

local tm_viewid<const> = viewidmgr.get "tonemapping"
local tm_e
function tm_sys:init()
    tm_e = ecs.create_entity {
        policy = {
            "ant.general|name",
            "ant.render|simplerender",
        },
        data = {
            name = "tonemapping_render_obj",
            simplemesh = imesh.init_mesh(ientity.quad_mesh()),
            material = "/pkg/ant.resources/materials/postprocess/tonemapping.material",
            scene = {srt = {},},
            render_object   = {},
            filter_state = "",
            visible = true,
            reference = true
        }
    }
end


local rt_flags<const> = sampler.sampler_flag {
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
}

function tm_sys:init_world()
    local vr = irq.view_rect "main_queue"
    ecs.create_entity {
        policy = {
            "ant.render|postprocess_queue",
            "ant.render|watch_screen_buffer",
            "ant.general|name",
        },
        data = {
            render_target = {
                viewid     = tm_viewid,
                view_rect   = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                view_mode = "",
                clear_state = {
                    clear = "",
                },
            },
            queue_name = "tonemapping_queue",
            watch_screen_buffer = true,
            name = "tonemapping_rt_obj",
            tonemapping_queue = true,
        }
    }
end

local pp_input0 = {
    stage = 0,
    texture={handle=nil},
}

function tm_sys:tonemapping()
    w:sync("render_object:in", tm_e)
    local ro = tm_e.render_object

    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi = pp.postprocess_input
    pp_input0.texture.handle = assert(ppi[1].handle)
    imaterial.set_property_directly(ro.properties, "s_postprocess_input0", pp_input0)
    irender.draw(tm_viewid, ro)
end