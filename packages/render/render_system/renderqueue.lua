local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local fbmgr = require "framebuffer_mgr"
local icamera = world:interface "ant.camera|camera"
local irq = ecs.interface "irenderqueue"

local function get_rt(qn)
	for qe in w:select(qn .. " render_target:in") do
		return qe.render_target
	end
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
	for qe in w:select(queuename .. " camera_eid:in") do
		return qe.camera_eid
	end
end

function irq.visible(queuename)
	-- visible is 'tag'
	for _ in w:select(queuename .. " visible") do
		return true
	end

	return false
end

function irq.main_camera()
	return irq.camera "main_queue"
end

local function view_clear(viewid, cs)
	bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	world:pub{"component_changed", "target_clear"}
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
	world:pub{"component_changed", "clear_state", queuename}
end

function irq.set_view_rect(queuename, rect)
	for qe in w:select(queuename .. " render_target:in camera_eid:in") do
		local rt = qe.render_target
		local vr = rt.view_rect
		vr.x, vr.y = rect.x, rect.y
		vr.w, vr.h = rect.w, rect.h
		icamera.set_frustum_aspect(qe.camera_eid, vr.w/vr.h)
		bgfx.set_view_rect(rt.viewid, vr.x, vr.y, vr.w, vr.h)
		world:pub{"component_changed", "view_rect", queuename}
	end
end

function irq.set_frame_buffer(queuename, fbidx)
	local rt = get_rt(queuename)
	rt.fb_idx = fbidx
end

function irq.set_camera(queuename, cameraeid)
	for qe in w:select(queuename .. " camera_eid:out") do
		qe.camera_eid = cameraeid
		world:pub{"component_changed", "camera_eid", queuename}
	end
end

function irq.set_visible(queuename, b)
	for qe in w:select(queuename .. " visible:out") do
		qe.visible = b
	
		world:pub{"component_changed", "visible", queuename}
	end
end

function irq.update_rendertarget(rt)
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
end

local rt_sys = ecs.system "render_target_system"
function rt_sys:entity_init()
	for v in w:select "INIT render_target:in name:in" do
		irq.update_rendertarget(v.render_target)
	end
end

function rt_sys:entity_remove()
	for v in w:select "REMOVED render_target:in" do
		fbmgr.unbind(v.render_target.viewid)
	end
end