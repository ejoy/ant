local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local fbmgr = require "framebuffer_mgr"
local icamera = world:interface "ant.camera|camera"
local irq = ecs.interface "irenderqueue"

function irq.viewid(eid)
	return world[eid].render_target.viewid
end

function irq.clear_state(eid)
	return world[eid].render_target.clear_state
end

function irq.view_rect(eid)
	return world[eid].render_target.view_rect
end

function irq.frame_buffer(eid)
	return world[eid].render_target.fb_idx
end

function irq.camera(eid)
	return world[eid].camera_eid
end

function irq.visible(eid)
	return world[eid].visible
end

function irq.main_camera()
	return irq.camera(world:singleton_entity_id "main_queue")
end

local function view_clear(viewid, cs)
	bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	world:pub{"component_changed", "target_clear"}
end

function irq.set_view_clear_state(eid, state)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.clear = state
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_color(eid, color)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.color = color
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_depth(eid, depth)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.depth = depth
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_stencil(eid, stencil)
	local rt = world[eid].render_target
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

function irq.set_view_clear(eid, what, color, depth, stencil, needtouch)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.color = color
	cs.depth = depth
	cs.stencil = stencil

	cs.clear = what
	local viewid = rt.viewid
	set_view_clear(viewid, cs)
	if needtouch then
		bgfx.touch(viewid)
	end
	world:pub{"component_changed", "clear_state", eid}
end

function irq.set_view_rect(eid, rect)
	local qe = world[eid]
	local rt = qe.render_target
	local vr = rt.view_rect
	vr.x, vr.y = rect.x, rect.y
	vr.w, vr.h = rect.w, rect.h
	icamera.set_frustum_aspect(qe.camera_eid, vr.w/vr.h)
	bgfx.set_view_rect(rt.viewid, vr.x, vr.y, vr.w, vr.h)
	world:pub{"component_changed", "view_rect", eid}
end

function irq.set_frame_buffer(eid, fbidx)
	local rt = world[eid].render_target
	rt.fb_idx = fbidx
	world:pub{"component_changed", "framebuffer", eid}
end

function irq.set_camera(eid, cameraeid)
	world[eid].camera_eid = cameraeid
	world:pub{"component_changed", "camera_eid", eid}
end

function irq.set_visible(eid, b)
	local q = world[eid]
	q.visible = b

	world:pub{"component_changed", "visible", eid}
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

local rt = ecs.component "render_target"
function rt:init()
	irq.update_rendertarget(self)
	return self
end

function rt:delete()
	fbmgr.unbind(self.viewid)
end