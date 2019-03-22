local ecs = ...
local world = ecs.world
local rhwi = require "hardware_interface"
local vp_detect = ecs.system "viewport_detect_system"
vp_detect.singleton "message"

function vp_detect:init()	
	-- local camera = entity.camera
	-- ms(camera.viewdir,{-25, -45, 0, 0}, "d=")
	-- ms(camera.eyepos, {5, 5, -5, 1}, "=")

	local function update_camera_viewrect(w, h)
		local maincamera = assert(world:first_entity("main_camera"))
		local vp = maincamera.viewport
		vp.rect.w, vp.rect.h = w, h
        maincamera.camera.frustum.aspect = w / h        
		rhwi.reset(nil, w, h)
    end
	
	local fb_size = world.args.fb_size
    update_camera_viewrect(fb_size.w, fb_size.h)
	self.message.observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end