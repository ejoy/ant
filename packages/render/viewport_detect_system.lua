local ecs = ...
local world = ecs.world
local fbmgr 	= require "framebuffer_mgr"

local vp_detect_sys = ecs.system "viewport_detect_system"

local icamera = world:interface "ant.camera|camera"

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

local function update_render_queue(q, viewsize)
	local vp = q.render_target.viewport
	local rt = vp.rect
	if viewsize then
		rt.w, rt.h = viewsize.w, viewsize.h
	end

	icamera.set_frustum_aspect(q.camera_eid, rt.w/rt.h)
	resize_framebuffer(rt.w, rt.h, q.render_target.fb_idx)
end

local function update_camera_viewrect(viewsize)
	local mq = world:singleton_entity "main_queue"
	update_render_queue(mq, viewsize)

	local bq = world:singleton_entity "blit_queue"
	if bq then
		update_render_queue(bq, viewsize)
	end
end

function vp_detect_sys:post_init()
	update_camera_viewrect()
end

function vp_detect_sys:data_changed()
	local new_fbw, new_fbh
	for _, w, h in eventResize:unpack() do
		if w ~= 0 and h ~= 0 then
			new_fbw, new_fbh = w, h
		end
	end

	if new_fbw then
		update_camera_viewrect{w=new_fbw, h=new_fbh}
	end
end
