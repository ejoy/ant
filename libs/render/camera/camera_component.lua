local ecs = ...
local world = ecs.world

ecs.import "render.window_component"
ecs.import "inputmgr.message_system"

-- camera entity
ecs.import "scene.filter.filter_component"
ecs.import "render.view_system"
ecs.import "render.components.general"

local math = import_package "math"
local mu = math.util
local ms = math.stack
local bgfx = require "bgfx"

-- 找时间统一到 render 中，作为要给独立的 viewid.lua 存放所有指定的 VIEW 
local VIEWID_MAINCAMERA = 100

ecs.tag "main_camera"

local camera_init_sys = ecs.system "camera_init"
camera_init_sys.singleton "message"
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
    -- create camera entity
	local camera_eid = world:new_entity("main_camera", 
		"viewid", "primitive_filter",
        "rotation", "position", 
        "frustum", 
        "view_rect", 
        "clear_component", 
        "name")

    local camera = world[camera_eid]
    camera.viewid = VIEWID_MAINCAMERA 
    camera.name = "main_camera"
    
    ms(camera.position,    {5, 5, -5, 1},  "=")
    ms(camera.rotation,   {-25, -45, 0, 0},   "=")

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
	self.message.observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end