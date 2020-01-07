local ecs = ...
local world = ecs.world

local rhwi 		= require "hardware_interface"
local fbmgr 	= require "framebuffer_mgr"
local camerautil= require "camera.util"

local vp_detect = ecs.system "viewport_detect_system"
vp_detect.require_system "ant.scene|primitive_filter_system"

local eventResize = world:sub {"resize"}
local camera_spawned_mb = world:sub {"camera_spawned", }

local function resize_framebuffer(w, h, fbidx, viewid)
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
	else
		rhwi.reset(nil, w, h)
	end
end

local function update_camera_viewrect(mq, w, h)
	local vp = mq.render_target.viewport
	local rt = vp.rect
	if w then rt.w = w else w = rt.w end
	if h then rt.h = h else h = rt.h end

	local camera = camerautil.get_camera(world, mq.camera_tag)
	if camera then
		camera.frustum.aspect = w / h
		resize_framebuffer(w, h, mq.render_target.fb_idx, mq.viewid)
	end
end

function vp_detect:init()
	local fb_size = world.args.fb_size
	update_camera_viewrect(world:first_entity "main_queue", fb_size.w, fb_size.h)
end

function vp_detect:data_changed()
	local mq = world:first_entity "main_queue"
	if mq then
		for _, w, h in eventResize:unpack() do
			update_camera_viewrect(mq, w, h)
		end

		for _, camearname in camera_spawned_mb:unpack() do
			if mq.camera_tag == camearname then
				update_camera_viewrect(mq)
			end
		end
	end
end
