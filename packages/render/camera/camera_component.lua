local ecs = ...
local world = ecs.world


ecs.import "ant.inputmgr"

-- camera entity




local math = import_package "ant.math"
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
	local fb_size = world.args.fb_size
	local frustum = {type="mat"}
	mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)
	local camera_eid = world:create_entity {
		main_camera = true,
		viewid = VIEWID_MAINCAMERA, 
		primitive_filter = {
			view_tag = "main_viewtag",
			filter_tag = "can_render",
			no_lighting  = false,
		},
		rotation = {-25, -45, 0, 0}, 
		position = {5, 5, -5, 1},
		frustum = frustum,
        view_rect = {x = 0, y = 0, w=fb_size.w, h=fb_size.h},
        clear_component = {
			color = 0x303030ff,
			depth = 1,
			stencil = 0,
		},
		name = "main_camera",		
	}

    local camera = world[camera_eid]
    local function update_camera_viewrect(w, h)
        local vr = camera.view_rect
        vr.w, vr.h = w, h
        self.window.width, self.window.height = w, h

        bgfx.reset(w, h, "v")
    end
    
    update_camera_viewrect(fb_size.w, fb_size.h)
	self.message.observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end