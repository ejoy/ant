local ecs = ...
local world = ecs.world

local mu = require "math.util"
local bgfx = require "bgfx"

-- 找时间统一到 render 中，作为要给独立的 viewid.lua 存放所有指定的 VIEW 
local VIEWID_MAINCAMERA = 100 

ecs.component "main_camera" {}

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

local function register_resize_message(update_size_op, observers)
    local message = {}
    function message:resize(w, h)
        update_size_op(w, h)
    end

    observers:add(message)
end

function camera_init_sys:init()
    local ms = self.math_stack
    -- create camera entity
    local camera_eid = world:new_entity("main_camera", "viewid", 
        "rotation", "position", 
        "frustum", 
        "view_rect", 
        "clear_component", 
        "name")

    local camera = world[camera_eid]
    camera.viewid.id = VIEWID_MAINCAMERA 
    camera.name.n = "main_camera"
    
    ms(camera.position.v,    {5, 5, -5, 1},  "=")
    ms(camera.rotation.v,   {-25, -45, 0, 0},   "=")

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

    register_resize_message(update_camera_viewrect, self.message_component.msg_observers)
end