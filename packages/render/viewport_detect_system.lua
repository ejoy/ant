local ecs = ...
local world = ecs.world
local w = world.w

local fbmgr 	= require "framebuffer_mgr"

local setting	= import_package "ant.settings".setting

local vp_detect_sys = ecs.system "viewport_detect_system"

local icamera	= ecs.import.interface "ant.camera|camera"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local eventResize = world:sub {"resize"}
local rb_cache = {}

local function resize_framebuffer(w, h, fbidx)
	if fbidx then
		local fb = fbmgr.get(fbidx)
		local changed = false
		local rbs = {}
		for _, rbidx in ipairs(fb)do
			rbs[#rbs+1] = rbidx
			local c = rb_cache[rbidx]
			if c == nil then
				changed = fbmgr.resize_rb(w, h, rbidx) or changed
				rb_cache[rbidx] = changed
			else
				changed = c
			end
		end
		
		if changed then
			fbmgr.recreate(fbidx, {render_buffers = rbs, manager_buffer = fb.manager_buffer})
		end
	end
end

local function update_render_queue(q, viewsize)
	local rt = q.render_target
	local vr = rt.view_rect
	if viewsize then
		vr.w, vr.h = viewsize.w, viewsize.h
	end

	if q.camera_ref then
		icamera.set_frustum_aspect(q.camera_ref, vr.w/vr.h)
	end
	resize_framebuffer(vr.w, vr.h, rt.fb_idx)
	irq.update_rendertarget(rt)
end

local function disable_resize()
	return setting:get "graphic/framebuffer/w" ~= nil
end

local function update_render_target(viewsize)
	if disable_resize() then
		return
	end
	rb_cache = {}
	w:clear "render_target_changed"
	for qe in w:select "watch_screen_buffer render_target:in camera_ref?in render_target_changed?out" do
		update_render_queue(qe, viewsize)
	end

	for qe in w:select "render_target:in watch_screen_buffer:absent" do
		local rt = qe.render_target
		local viewid = rt.viewid
		local fbidx = rt.fb_idx
		fbmgr.bind(viewid, fbidx)
	end
end

function vp_detect_sys:post_init()
	update_render_target()
end

function vp_detect_sys:data_changed()
	local new_fbw, new_fbh
	for _, w, h in eventResize:unpack() do
		if w ~= 0 and h ~= 0 then
			new_fbw, new_fbh = w, h
		end
	end

	if new_fbw then
		update_render_target{w=new_fbw, h=new_fbh}
	end
end
