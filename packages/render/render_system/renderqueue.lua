local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local fbmgr = require "framebuffer_mgr"
local icamera = ecs.import.interface "ant.camera|icamera"
local irq = ecs.interface "irenderqueue"

local function get_rt(queuename)
	local qe = w:singleton(queuename, "render_target:in")
	return qe.render_target
end

function irq.viewid(queuename)
	return get_rt(queuename).viewid
end

function irq.clear_state(queuename)
	return get_rt(queuename).clear_state
end

function irq.view_rect(queuename)
	return get_rt(queuename).view_rect
end

function irq.frame_buffer(queuename)
	return get_rt(queuename).fb_idx
end

function irq.camera(queuename)
	local qe = w:singleton(queuename, "camera_ref:in")
	return qe.camera_ref
end

function irq.visible(queuename)
	local qe = w:singleton(queuename, "visible:in")
	return qe.visible
end

function irq.main_camera()
	return irq.camera "main_queue"
end

local function view_clear(viewid, cs, queuename)
	bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	world:pub{"clear_state_changed", queuename}
end

function irq.set_view_clear_state(queuename, state)
	local rt = get_rt(queuename)
	local cs = rt.clear_state
	cs.clear = state
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_color(queuename, color)
	local rt = get_rt(queuename)
	local cs = rt.clear_state
	cs.color = color
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_depth(queuename, depth)
	local rt = get_rt(queuename)
	local cs = rt.clear_state
	cs.depth = depth
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_stencil(queuename, stencil)
	local rt = get_rt(queuename)
	local cs = rt.clear_state
	cs.stencil = stencil
	view_clear(rt.viewid, cs)
end

local clear_colornames<const> = {
	"color1", "color2","color3","color4","color5","color6", "color7"
}

local function set_view_clear(viewid, cs)
	-- if cs.color1 then
	-- 	bgfx.set_view_clear_mrt(viewid, cs.clear, cs.depth, cs.stencil,
	-- 		cs.color, cs.color1, cs.color2, cs.color3,
	-- 		cs.color4, cs.color5, cs.color6, cs.color7)
	-- else
		bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	-- end
end

function irq.set_view_clear(queuename, what, color, depth, stencil)
	local rt = get_rt(queuename)
	local cs = rt.clear_state
	cs.color = color
	cs.depth = depth
	cs.stencil = stencil

	cs.clear = what
	local viewid = rt.viewid
	set_view_clear(viewid, cs)
	world:pub{"clear_state_changed", queuename, cs}
end

function irq.set_view_rect(queuename, rect)
	local qe = w:singleton(queuename, "render_target:in camera_ref?in")
	local rt = qe.render_target
	local vr = rt.view_rect
	vr.x, vr.y = rect.x, rect.y
	vr.w, vr.h = rect.w, rect.h
	if qe.camera_ref then
		icamera.set_frustum_aspect(qe.camera_ref, vr.w/vr.h)
	end
	bgfx.set_view_rect(rt.viewid, vr.x, vr.y, vr.w, vr.h)
	world:pub{"view_rect_changed", queuename, rect}
end

function irq.set_frame_buffer(queuename, fbidx)
	local rt = get_rt(queuename)
	rt.fb_idx = fbidx
	world:pub{"framebuffer_changed", queuename, fbidx}
end

function irq.set_camera(queuename, camera_ref)
	local changed
	for q in w:select(queuename .. " camera_ref:out render_target:in") do
		q.camera_ref = camera_ref
		local rt = q.render_target
		local vr = rt.view_rect
		icamera.set_frustum_aspect(camera_ref, vr.w / vr.h)
		changed = true
		world:pub{queuename, "camera_changed", camera_ref}
	end

	if not changed then
		error(("invalid queuename %s, not found"):format(queuename))
	end
end

local bc_mb = world:sub{"bind_camera"}
function ecs.method.bind_camera(camera_ref, queuename)
	world:pub{"bind_camera", queuename, camera_ref}
end

function irq.set_visible(queuename, b)
	local qe = {visible = b}
	w:singleton(queuename, "visible?out", qe)
	world:pub{"queue_visible_changed", queuename, b}
end

function irq.update_rendertarget(rt, need_touch)
	local viewid = rt.viewid
	local vm = rt.view_mode or ""
	bgfx.set_view_mode(viewid, vm)
	local vr = rt.view_rect
	bgfx.set_view_rect(viewid, vr.x, vr.y, vr.w, vr.h)
	local cs = rt.clear_state
	set_view_clear(viewid, cs)
	
	local fb_idx = rt.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		rt.fb_idx = fbmgr.get_fb_idx(viewid)
	end

	if need_touch then
		bgfx.touch(viewid)
	end
end

local rt_sys = ecs.system "render_target_system"
function rt_sys:entity_init()
	for msg in bc_mb:each() do
		local qn, c = msg[2], msg[3]
		irq.set_camera(qn, c)
	end

	for e in w:select "INIT render_target:in name:in need_touch?in" do
		irq.update_rendertarget(e.render_target, e.need_touch)
	end
	w:clear "need_touch"
end

function rt_sys:entity_ready()
end

function rt_sys:entity_remove()
	for v in w:select "REMOVED render_target:in" do
		fbmgr.unbind(v.render_target.viewid)
	end
end
