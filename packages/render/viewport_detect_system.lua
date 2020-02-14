local ecs = ...
local world = ecs.world

local rhwi 		= require "hardware_interface"
local fbmgr 	= require "framebuffer_mgr"
local camerautil= require "camera.util"

local vp_detect = ecs.system "viewport_detect_system"
vp_detect.require_system "ant.scene|primitive_filter_system"

local eventResize = world:sub {"resize"}

local function resize_framebuffer(w, h, fbidx)
	if fbidx then
		local fb = fbmgr.get(fbidx)
		local changed = false
		local rbs = {}
		for _, rbidx in ipairs(fb)do
			rbs[#rbs+1] = rbidx
			changed = fbmgr.resize_rb(w, h, rbidx) or changed
		end
		
		if changed then
			fbmgr.recreate(fbidx, {render_buffers = rbs, manager_buffer = fb.manager_buffer})
		end
	end
end

local function update_render_queue(q, w, h)
	local vp = q.render_target.viewport
	local rt = vp.rect
	rt.w, rt.h = w, h

	local ce = world[q.camera_eid]
	if ce then
		local camera = ce.camera
		camera.frustum.aspect = w / h
		resize_framebuffer(w, h, q.render_target.fb_idx)
	end
end

local function update_camera_viewrect(w, h)
	local mq = world:singleton_entity "main_queue"
	update_render_queue(mq, w, h)

	local bq = world:singleton_entity "blit_queue"
	update_render_queue(bq, w, h)
end

function vp_detect:post_init()
	local fb_size = world.args.fb_size
	update_camera_viewrect(fb_size.w, fb_size.h)
end

function vp_detect:data_changed()
	local new_fbw, new_fbh
	for _, w, h in eventResize:unpack() do
		new_fbw, new_fbh = w, h
	end

	if new_fbw then
		local fbsize = world.args.fb_size
		fbsize.w, fbsize.h = new_fbw, new_fbh
		update_camera_viewrect(new_fbw, new_fbh)
	end
end
