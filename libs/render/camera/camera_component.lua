local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.window_component"
ecs.import "inputmgr.message_system"

-- camera entity
ecs.import "scene.filter_component"
ecs.import "render.view_system"

local mu = require "math.util"
local bgfx = require "bgfx"

ecs.tag "main_camera"

local camera_init_sys = ecs.system "camera_init"
camera_init_sys.singleton "math_stack"
camera_init_sys.singleton "message_component"
camera_init_sys.singleton "window"

-- local function update_main_camera_viewrect(w, h)	
-- 	local vr = camera.view_rect
-- 	vr.x, vr.y, vr.w, vr.h = 0, 0, w, h
-- 		-- will not consider camera view_rect not full cover framebuffer case
-- 		-- local old_w, old_h = win.width, win.height
-- 		-- local vr = camera.view_rect
-- 		-- local newx = 0
-- 		-- local newx_end = w
-- 		-- if vr.x ~= 0 then
-- 		-- 	newx = math.floor((vr.x / old_w) * w)
-- 		-- 	newx_end = math.floor(((vr.x + vr.w) / old_w) * w)
-- 		-- end

-- 		-- local newy = 0
-- 		-- local newy_end = h
-- 		-- if vr.y ~= 0 then
-- 		-- 	newy = math.floor((vr.y / old_h) * h)
-- 		-- 	newy_end = math.floor(((vr.y + vr.h) / old_h) * h)
-- end

function camera_init_sys:init()
    local ms = self.math_stack
    -- create camera entity
	local camera_eid = world:new_entity("main_camera", 
		"viewid", "primitive_filter",
        "rotation", "position", 
        "frustum", 
        "view_rect", 
        "clear_component", 
        "name")

    local camera = world[camera_eid]
    camera.viewid.id = 0
    camera.name.n = "main_camera"
    
    ms(camera.position,    {5, 5, -5, 1},  "=")
    ms(camera.rotation,   {45, -45, 0, 0},   "=")

    local frustum = camera.frustum
    mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)

    local function update_camera_viewrect(w, h)
        local vr = camera.view_rect
        vr.w, vr.h = w, h
        self.window.width, self.window.height = w, h

        bgfx.reset(w, h, "v")
    end
    local fb_size = world.args.fb_size
    update_camera_viewrect(fb_size.w, fb_size.h)
	self.message_component.msg_observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end