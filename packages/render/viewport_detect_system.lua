local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local rhwi = require "hardware_interface"
local fbmgr = require "framebuffer_mgr"
local util = require "util"
local bgfx = require "bgfx"

local vp_detect = ecs.system "viewport_detect_system"
vp_detect.singleton "message"

local function resize_renderbuffer(w, h, rb)
	if rb.w ~= w or rb.h ~= h then
		rb.w, rb.h = w, h
		bgfx.destroy(assert(rb.handle))
		rb.handle = util.create_renderbuffer(rb)
		return true
	end
end

local function resize_framebuffer(w, h, fb, viewid)
	if fb then
		local rbs = assert(fb.render_buffers)
		local changed = false
		for _, rb in ipairs(rbs)do
			changed = (resize_renderbuffer(w, h, rb) ~= nil) or changed
		end
		
		if changed then
			fbmgr.unbind(viewid)
			bgfx.destroy(fb.handle)
			fb.handle = util.create_framebuffer(rbs, fb.manager_buffer)
		end
	else
		rhwi.reset(nil, w, h)
	end	
end

function vp_detect:init()	
	-- local camera = entity.camera
	-- ms(camera.viewdir,{-25, -45, 0, 0}, "d=")
	-- ms(camera.eyepos, {5, 5, -5, 1}, "=")

	local function update_camera_viewrect(w, h)
		local mq = world:first_entity("main_queue")
		if mq == nil then
			return 
		end
		local vp = mq.render_target.viewport
		vp.rect.w, vp.rect.h = w, h
		mq.camera.frustum.aspect = w / h
		
		resize_framebuffer(w, h, mq.render_target.frame_buffer, mq.viewid)
		local hub = world.args.hub
		if hub then
			hub.publish("framebuffer_change")
		end
    end
	
	local fb_size = world.args.fb_size
    update_camera_viewrect(fb_size.w, fb_size.h)
	self.message.observers:add {
		resize = function(_, w, h) update_camera_viewrect(w, h) end
	}
end