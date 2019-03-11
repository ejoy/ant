local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math = import_package "ant.math"
local mu = math.util
local ms = math.stack
local bgfx = require "bgfx"

local VIEWID_MAINCAMERA = 100

ecs.tag "main_camera"

ecs.component_alias("view_tag", "string")
ecs.component_alias("filter_tag", "string")

ecs.component_alias("viewid", "int", 0)

ecs.component "camera"
	.type "string"
	.eyepos	"vector"
	.viewdir"vector"
	.frustum"frustum"
	.viewid	"viewid"	

local camera_init_sys = ecs.system "camera_init"
camera_init_sys.singleton "message"
camera_init_sys.singleton "window"

function camera_init_sys:init()
	local fb_size = world.args.fb_size
	local frustum = {type="mat"}
	mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)

	local camera_eid = world:create_entity {
		main_camera = true,
		camera = {
			type = "",
			eyepos = {0, 0, 0, 1},
			viewdir = {0, 0, 0, 0},
			frustum = frustum,
			viewid = VIEWID_MAINCAMERA,
		},
        view_rect = {
			x = 0, y = 0, 
			w=fb_size.w, h=fb_size.h
		},
        clear_component = {
			color = 0x303030ff,
			depth = 1,
			stencil = 0,
		},
		name = "main_camera",
		primitive_filter = {
			view_tag = "main_viewtag",
			filter_tag = "can_render",
			no_lighting  = false,		
		}
	}

	local entity = world[camera_eid]	
	local camera = entity.camera
	ms(camera.viewdir,{-25, -45, 0, 0}, "d=")
	ms(camera.eyepos, {5, 5, -5, 1}, "=")
    local function update_camera_viewrect(w, h)
        local vr = entity.view_rect
        vr.w, vr.h = w, h
        self.window.width, self.window.height = w, h

        bgfx.reset(w, h, "vmx")
    end
    
    update_camera_viewrect(fb_size.w, fb_size.h)
	self.message.observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end