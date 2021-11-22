local ecs 	= ...
local world = ecs.world
local w 	= world.w

local mathpkg 	= import_package "ant.math"
local mu 		= mathpkg.util

local viewidmgr = require "viewid_mgr"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local ientity 	= ecs.import.interface "ant.render|ientity"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local irender	= ecs.import.interface "ant.render|irender"
local imesh		= ecs.import.interface "ant.asset|imesh"

local blit_sys 	= ecs.system "blit_system"

local blit_viewid = viewidmgr.get "blit"

function blit_sys:init()
	ecs.create_entity {
		policy = {
			"ant.general|name",
			"ant.render|simplerender",
		},
		data = {
			scene = {
				srt = mu.srt_obj(),
			},
			material        = "/pkg/ant.resources/materials/fullscreen.material",
			filter_state    = "",
			name            = "resolve_quad",
			simplemesh      = imesh.init_mesh(ientity.fullquad_mesh(), true),
			blit_obj		= true,
		}
	}
end

function blit_sys:init_world()
	local vr = irq.view_rect "main_queue"
    ecs.create_entity {
        policy = {
            "ant.render|postprocess_queue",
            "ant.render|watch_screen_buffer",
            "ant.general|name",
        },
        data = {
            render_target = {
                viewid     	= blit_viewid,
                view_rect  	= {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                view_mode 	= "",
                clear_state = {clear = "",},
            },
            watch_screen_buffer = true,
            name = "blit_queue",
        }
    }
end

local pp_input0 = {
    stage = 0,
    texture={handle=nil},
}

function blit_sys:blit()
	local b = w:singleton("blit_obj", "render_object:in")
	local ro = b.render_object

	local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi = pp.postprocess_input
    pp_input0.texture.handle = assert(ppi[1].handle)
    imaterial.set_property_directly(ro.properties, "s_postprocess_input0", pp_input0)

	irender.draw(blit_viewid, ro)
end