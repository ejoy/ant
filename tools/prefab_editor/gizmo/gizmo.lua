local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.import.interface "ant.asset|imaterial"
local ivs = ecs.import.interface "ant.scene|ivisible_state"
local math3d = require "math3d"
local gizmo_const = require "gizmo.const"
local gizmo = {
    mode = gizmo_const.SELECT,
	scale = 1.0,
	--move
	tx = {dir = gizmo_const.DIR_X, color = math3d.ref(math3d.vector(gizmo_const.COLOR.X))},
	ty = {dir = gizmo_const.DIR_Y, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Y))},
	tz = {dir = gizmo_const.DIR_Z, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Z))},
	txy = {dir = gizmo_const.DIR_Z, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Z_ALPHA)), area = gizmo_const.RIGHT_TOP},
	tyz = {dir = gizmo_const.DIR_X, color = math3d.ref(math3d.vector(gizmo_const.COLOR.X_ALPHA)), area = gizmo_const.RIGHT_TOP},
	tzx = {dir = gizmo_const.DIR_Y, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Y_ALPHA)), area = gizmo_const.RIGHT_TOP},
	--rotate
	rx = {dir = gizmo_const.DIR_X, color = math3d.ref(math3d.vector(gizmo_const.COLOR.X))},
	ry = {dir = gizmo_const.DIR_Y, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Y))},
	rz = {dir = gizmo_const.DIR_Z, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Z))},
	rw = {dir = gizmo_const.DIR_Z, color = math3d.ref(math3d.vector(gizmo_const.COLOR.GRAY))},
	--scale
	sx = {dir = gizmo_const.DIR_X, color = math3d.ref(math3d.vector(gizmo_const.COLOR.X))},
	sy = {dir = gizmo_const.DIR_Y, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Y))},
	sz = {dir = gizmo_const.DIR_Z, color = math3d.ref(math3d.vector(gizmo_const.COLOR.Z))},
}

local function highlight_axis(axis)
	local e1 <close> = w:entity(axis.eid[1])
	local e2 <close> = w:entity(axis.eid[2])
	imaterial.set_property(e1, "u_color", gizmo_const.COLOR.HIGHLIGHT)
	imaterial.set_property(e2, "u_color", gizmo_const.COLOR.HIGHLIGHT)
end

local function gray_axis(axis)
	local e1 <close> = w:entity(axis.eid[1])
	local e2 <close> = w:entity(axis.eid[2])
	imaterial.set_property(e1, "u_color", gizmo_const.COLOR.GRAY_ALPHA)
	imaterial.set_property(e2, "u_color", gizmo_const.COLOR.GRAY_ALPHA)
end

function gizmo:highlight_axis_plane(axis_plane)
	local e <close> = w:entity(axis_plane.eid[1])
	imaterial.set_property(e, "u_color", gizmo_const.COLOR.HIGHLIGHT_ALPHA)
	if axis_plane == self.tyz then
		highlight_axis(self.ty)
		highlight_axis(self.tz)
	elseif axis_plane == self.txy then
		highlight_axis(self.tx)
		highlight_axis(self.ty)
	elseif axis_plane == self.tzx then
		highlight_axis(self.tz)
		highlight_axis(self.tx)
	end
end

function gizmo:highlight_axis_or_plane(axis)
	if not axis then return end

	if axis == self.tyz or axis == self.txy or axis == self.tzx then
		self:highlight_axis_plane(axis)
	else
		highlight_axis(axis)
	end
end

local function set_visible(eid, b)
	local e <close> = w:entity(eid)
	ivs.set_state(e, "main_view", b)
	ivs.set_state(e, "selectable", b)
end

function gizmo:click_axis(axis)
	if not axis then return end

	if self.mode == gizmo_const.SCALE then
		if axis == self.sx then
			gray_axis(self.sy)
			gray_axis(self.sz)
		elseif axis == self.sy then
			gray_axis(self.sx)
			gray_axis(self.sz)
		elseif axis == self.sz then
			gray_axis(self.sx)
			gray_axis(self.sy)
		end
	elseif self.mode == gizmo_const.ROTATE then
		if axis == self.rx then
			gray_axis(self.ry)
			gray_axis(self.rz)
		elseif axis == self.ry then
			gray_axis(self.rx)
			gray_axis(self.rz)
		elseif axis == self.rz then
			gray_axis(self.rx)
			gray_axis(self.ry)
		elseif axis == self.rw then
			gray_axis(self.rx)
			gray_axis(self.ry)
			gray_axis(self.rz)
		end
	else
		set_visible(self.tyz.eid[1], false)
		set_visible(self.txy.eid[1], false)
		set_visible(self.tzx.eid[1], false)
		if axis == self.tx then
			gray_axis(self.ty)
			gray_axis(self.tz)
		elseif axis == self.ty then
			gray_axis(self.tx)
			gray_axis(self.tz)
		elseif axis == self.tz then
			gray_axis(self.tx)
			gray_axis(self.ty)
		end
	end
end

function gizmo:click_plane(axis)
	if axis == self.tyz then
		gray_axis(self.tx)
		set_visible(self.txy.eid[1], false)
		set_visible(self.tzx.eid[1], false)
	elseif axis == self.txy then
		gray_axis(self.tz)
		set_visible(self.tyz.eid[1], false)
		set_visible(self.tzx.eid[1], false)
	elseif axis == self.tzx then
		gray_axis(self.ty)
		set_visible(self.txy.eid[1], false)
		set_visible(self.tyz.eid[1], false)
	end
end

function gizmo:click_axis_or_plane(axis)
	if not axis then return end

	if axis == self.tyz or axis == self.txy or axis == self.tzx then
		self:click_plane(axis)
	else
		self:click_axis(axis)
	end
end

function gizmo:hide_rotate_fan()
	if not self.rx.eid then return end
	set_visible(self.rx.eid[3], false)
	set_visible(self.rx.eid[4], false)
	set_visible(self.ry.eid[3], false)
	set_visible(self.ry.eid[4], false)
	set_visible(self.rz.eid[3], false)
	set_visible(self.rz.eid[4], false)
	set_visible(self.rw.eid[3], false)
	set_visible(self.rw.eid[4], false)
end

function gizmo:show_move(show)
	if not self.tx.eid then return end
	set_visible(self.tx.eid[1], show)
	set_visible(self.tx.eid[2], show)
	set_visible(self.ty.eid[1], show)
	set_visible(self.ty.eid[2], show)
	set_visible(self.tz.eid[1], show)
	set_visible(self.tz.eid[2], show)
	--
	if not self.txy.eid then return end
	set_visible(self.txy.eid[1], show)
	set_visible(self.tyz.eid[1], show)
	set_visible(self.tzx.eid[1], show)
end

function gizmo:show_rotate(show)
	if not self.rx.eid then return end
	set_visible(self.rx.eid[1], show)
	set_visible(self.rx.eid[2], show)
	set_visible(self.ry.eid[1], show)
	set_visible(self.ry.eid[2], show)
	set_visible(self.rz.eid[1], show)
	set_visible(self.rz.eid[2], show)
	set_visible(self.rw.eid[1], show)
end

function gizmo:show_scale(show)
	if not self.sx.eid then return end
	set_visible(self.sx.eid[1], show)
	set_visible(self.sx.eid[2], show)
	set_visible(self.sy.eid[1], show)
	set_visible(self.sy.eid[2], show)
	set_visible(self.sz.eid[1], show)
	set_visible(self.sz.eid[2], show)
	set_visible(self.uniform_scale_eid, show)
end

function gizmo:show_by_state(show)
	if show and not self.target_eid then
		return
	end
	if self.mode == gizmo_const.MOVE then
		self:show_move(show)
	elseif self.mode == gizmo_const.ROTATE then
		self:show_rotate(show)
	elseif self.mode == gizmo_const.SCALE then
		self:show_scale(show)
	else
		self:show_move(false)
		self:show_rotate(false)
		self:show_scale(false)
	end
end

function gizmo:reset_move_axis_color()
	if self.mode ~= gizmo_const.MOVE then return end
	local uname = "u_color"
	local tx1 <close> = w:entity(self.tx.eid[1])
	local tx2 <close> = w:entity(self.tx.eid[2])
	local ty1 <close> = w:entity(self.ty.eid[1])
	local ty2 <close> = w:entity(self.ty.eid[2])
	local tz1 <close> = w:entity(self.tz.eid[1])
	local tz2 <close> = w:entity(self.tz.eid[2])
	imaterial.set_property(tx1, uname, self.tx.color)
	imaterial.set_property(tx2, uname, self.tx.color)
	imaterial.set_property(ty1, uname, self.ty.color)
	imaterial.set_property(ty2, uname, self.ty.color)
	imaterial.set_property(tz1, uname, self.tz.color)
	imaterial.set_property(tz2, uname, self.tz.color)
	--plane
	set_visible(self.txy.eid[1], self.target_eid ~= nil)
	set_visible(self.tyz.eid[1], self.target_eid ~= nil)
	set_visible(self.tzx.eid[1], self.target_eid ~= nil)
	local txy <close> = w:entity(self.txy.eid[1])
	local tyz <close> = w:entity(self.tyz.eid[1])
	local tzx <close> = w:entity(self.tzx.eid[1])
	imaterial.set_property(txy, uname, self.txy.color)
	imaterial.set_property(tyz, uname, self.tyz.color)
	imaterial.set_property(tzx, uname, self.tzx.color)
end

function gizmo:reset_rotate_axis_color()
	local uname = "u_color"
	local rx1 <close> = w:entity(self.rx.eid[1])
	local rx2 <close> = w:entity(self.rx.eid[2])
	local ry1 <close> = w:entity(self.ry.eid[1])
	local ry2 <close> = w:entity(self.ry.eid[2])
	local rz1 <close> = w:entity(self.rz.eid[1])
	local rz2 <close> = w:entity(self.rz.eid[2])
	local rw <close> = w:entity(self.rw.eid[1])
	imaterial.set_property(rx1, uname, self.rx.color)
	imaterial.set_property(rx2, uname, self.rx.color)
	imaterial.set_property(ry1, uname, self.ry.color)
	imaterial.set_property(ry2, uname, self.ry.color)
	imaterial.set_property(rz1, uname, self.rz.color)
	imaterial.set_property(rz2, uname, self.rz.color)
	imaterial.set_property(rw, uname, self.rw.color)
end

function gizmo:reset_scale_axis_color()
	local uname = "u_color"
	local sx1 <close> = w:entity(self.sx.eid[1])
	local sx2 <close> = w:entity(self.sx.eid[2])
	local sy1 <close> = w:entity(self.sy.eid[1])
	local sy2 <close> = w:entity(self.sy.eid[2])
	local sz1 <close> = w:entity(self.sz.eid[1])
	local sz2 <close> = w:entity(self.sz.eid[2])
	local us <close> = w:entity(self.uniform_scale_eid)
	imaterial.set_property(sx1, uname, self.sx.color)
	imaterial.set_property(sx2, uname, self.sx.color)
	imaterial.set_property(sy1, uname, self.sy.color)
	imaterial.set_property(sy2, uname, self.sy.color)
	imaterial.set_property(sz1, uname, self.sz.color)
	imaterial.set_property(sz2, uname, self.sz.color)
	imaterial.set_property(us, uname, math3d.vector(gizmo_const.COLOR.GRAY))
end

return gizmo