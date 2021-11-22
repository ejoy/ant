local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.import.interface "ant.asset|imaterial"
local ies = ecs.import.interface "ant.scene|ifilter_state"

local gizmo_const = require "gizmo.const"
local gizmo = {
    mode = gizmo_const.SELECT,
	--move
	tx = {dir = gizmo_const.DIR_X, color = gizmo_const.COLOR_X},
	ty = {dir = gizmo_const.DIR_Y, color = gizmo_const.COLOR_Y},
	tz = {dir = gizmo_const.DIR_Z, color = gizmo_const.COLOR_Z},
	txy = {dir = gizmo_const.DIR_Z, color = gizmo_const.COLOR_Z_ALPHA, area = right_top},
	tyz = {dir = gizmo_const.DIR_X, color = gizmo_const.COLOR_X_ALPHA, area = right_top},
	tzx = {dir = gizmo_const.DIR_Y, color = gizmo_const.COLOR_Y_ALPHA, area = right_top},
	--rotate
	rx = {dir = gizmo_const.DIR_X, color = gizmo_const.COLOR_X},
	ry = {dir = gizmo_const.DIR_Y, color = gizmo_const.COLOR_Y},
	rz = {dir = gizmo_const.DIR_Z, color = gizmo_const.COLOR_Z},
	rw = {dir = gizmo_const.DIR_Z, color = gizmo_const.COLOR_GRAY},
	--scale
	sx = {dir = gizmo_const.DIR_X, color = gizmo_const.COLOR_X},
	sy = {dir = gizmo_const.DIR_Y, color = gizmo_const.COLOR_Y},
	sz = {dir = gizmo_const.DIR_Z, color = gizmo_const.COLOR_Z},
}

local function highlight_axis(axis)
	imaterial.set_property(axis.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
	imaterial.set_property(axis.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
end

local function gray_axis(axis)
	imaterial.set_property(axis.eid[1], "u_color", gizmo_const.COLOR_GRAY_ALPHA)
	imaterial.set_property(axis.eid[2], "u_color", gizmo_const.COLOR_GRAY_ALPHA)
end

function gizmo:highlight_axis_plane(axis_plane)
	imaterial.set_property(axis_plane.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR_ALPHA)
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
		local state = "main_view"
		ies.set_state(self.tyz.eid[1], state, false)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
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
	local state = "main_view"
	if axis == self.tyz then
		gray_axis(self.tx)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
	elseif axis == self.txy then
		gray_axis(self.tz)
		ies.set_state(self.tyz.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
	elseif axis == self.tzx then
		gray_axis(self.ty)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tyz.eid[1], state, false)
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
	local state = "main_view"
	if not self.rx.eid then return end
	ies.set_state(self.rx.eid[3], state, false)
	ies.set_state(self.rx.eid[4], state, false)
	ies.set_state(self.ry.eid[3], state, false)
	ies.set_state(self.ry.eid[4], state, false)
	ies.set_state(self.rz.eid[3], state, false)
	ies.set_state(self.rz.eid[4], state, false)
	ies.set_state(self.rw.eid[3], state, false)
	ies.set_state(self.rw.eid[4], state, false)
end

function gizmo:show_move(show)
	local state = "main_view"
	if not self.tx.eid then return end
	ies.set_state(self.tx.eid[1], state, show)
	ies.set_state(self.tx.eid[2], state, show)
	ies.set_state(self.ty.eid[1], state, show)
	ies.set_state(self.ty.eid[2], state, show)
	ies.set_state(self.tz.eid[1], state, show)
	ies.set_state(self.tz.eid[2], state, show)
	--
	if not self.txy.eid then return end
	ies.set_state(self.txy.eid[1], state, show)
	ies.set_state(self.tyz.eid[1], state, show)
	ies.set_state(self.tzx.eid[1], state, show)
end

function gizmo:show_rotate(show)
	local state = "main_view"
	if not self.rx.eid then return end
	ies.set_state(self.rx.eid[1], state, show)
	ies.set_state(self.rx.eid[2], state, show)
	ies.set_state(self.ry.eid[1], state, show)
	ies.set_state(self.ry.eid[2], state, show)
	ies.set_state(self.rz.eid[1], state, show)
	ies.set_state(self.rz.eid[2], state, show)
	ies.set_state(self.rw.eid[1], state, show)
end

function gizmo:show_scale(show)
	local state = "main_view"
	if not self.sx.eid then return end
	ies.set_state(self.sx.eid[1], state, show)
	ies.set_state(self.sx.eid[2], state, show)
	ies.set_state(self.sy.eid[1], state, show)
	ies.set_state(self.sy.eid[2], state, show)
	ies.set_state(self.sz.eid[1], state, show)
	ies.set_state(self.sz.eid[2], state, show)
	ies.set_state(self.uniform_scale_eid, state, show)
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
	imaterial.set_property(self.tx.eid[1], uname, self.tx.color)
	imaterial.set_property(self.tx.eid[2], uname, self.tx.color)
	imaterial.set_property(self.ty.eid[1], uname, self.ty.color)
	imaterial.set_property(self.ty.eid[2], uname, self.ty.color)
	imaterial.set_property(self.tz.eid[1], uname, self.tz.color)
	imaterial.set_property(self.tz.eid[2], uname, self.tz.color)
	--plane
	ies.set_state(self.txy.eid[1], "visible", self.target_eid ~= nil)
	ies.set_state(self.tyz.eid[1], "visible", self.target_eid ~= nil)
	ies.set_state(self.tzx.eid[1], "visible", self.target_eid ~= nil)
	imaterial.set_property(self.txy.eid[1], uname, self.txy.color)
	imaterial.set_property(self.tyz.eid[1], uname, self.tyz.color)
	imaterial.set_property(self.tzx.eid[1], uname, self.tzx.color)
end

function gizmo:reset_rotate_axis_color()
	local uname = "u_color"
	imaterial.set_property(self.rx.eid[1], uname, self.rx.color)
	imaterial.set_property(self.rx.eid[2], uname, self.rx.color)
	imaterial.set_property(self.ry.eid[1], uname, self.ry.color)
	imaterial.set_property(self.ry.eid[2], uname, self.ry.color)
	imaterial.set_property(self.rz.eid[1], uname, self.rz.color)
	imaterial.set_property(self.rz.eid[2], uname, self.rz.color)
	imaterial.set_property(self.rw.eid[1], uname, self.rw.color)
end

function gizmo:reset_scale_axis_color()
	local uname = "u_color"
	imaterial.set_property(self.sx.eid[1], uname, self.sx.color)
	imaterial.set_property(self.sx.eid[2], uname, self.sx.color)
	imaterial.set_property(self.sy.eid[1], uname, self.sy.color)
	imaterial.set_property(self.sy.eid[2], uname, self.sy.color)
	imaterial.set_property(self.sz.eid[1], uname, self.sz.color)
	imaterial.set_property(self.sz.eid[2], uname, self.sz.color)
	imaterial.set_property(self.uniform_scale_eid, uname, gizmo_const.COLOR_GRAY)
end

return gizmo