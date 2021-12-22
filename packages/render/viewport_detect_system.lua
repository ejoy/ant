local ecs = ...
local world = ecs.world
local w = world.w

local fbmgr 	= require "framebuffer_mgr"

local setting	= import_package "ant.settings".setting

local vp_detect_sys = ecs.system "viewport_detect_system"

local icamera	= ecs.import.interface "ant.camera|icamera"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local view_resize_mb = world:sub {"view_resize"}
local fb_cache, rb_cache
local function clear_cache()
	fb_cache, rb_cache = {}, {}
end

local function resize_framebuffer(w, h, fbidx)
	if fbidx == nil or fb_cache[fbidx] then
		return 
	end

	local fb = fbmgr.get(fbidx)
	fb_cache[fbidx] = fb

	local changed = false
	local rbs = {}
	for _, attachment in ipairs(fb)do
		local rbidx = attachment.rbidx
		rbs[#rbs+1] = attachment
		local c = rb_cache[rbidx]
		if c == nil then
			changed = fbmgr.resize_rb(w, h, rbidx) or changed
			rb_cache[rbidx] = changed
		else
			changed = true
		end
	end
	
	if changed then
		fbmgr.recreate(fbidx, fb)
	end
end

local function update_render_queue(q, viewsize)
	local rt = q.render_target
	local vr = rt.view_rect
	if viewsize then
		if vr.w == viewsize.w and vr.h == viewsize.h then
			return
		end
		vr.w, vr.h = viewsize.w, viewsize.h
	end

	if q.camera_ref then
		icamera.set_frustum_aspect(q.camera_ref, vr.w/vr.h)
	end
	resize_framebuffer(vr.w, vr.h, rt.fb_idx)
	irq.update_rendertarget(q.queue_name, rt)
end

local function disable_resize()
	return setting:get "graphic/framebuffer/w" ~= nil or setting:get "graphic/framebuffer/ratio" ~= nil
end

local function update_render_target(viewsize)
	if disable_resize() then
		return
	end
	clear_cache()
	for qe in w:select "watch_screen_buffer render_target:in queue_name:in camera_ref?in" do
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
	for _, w, h in view_resize_mb:unpack() do
		if w ~= 0 and h ~= 0 then
			new_fbw, new_fbh = w, h
		end
	end

	if new_fbw then
		update_render_target{w=new_fbw, h=new_fbh}
	end
end
