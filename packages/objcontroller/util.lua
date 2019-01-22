local util = {}; util.__index = util

local math3d = import_package "ant.math"
local mu = math3d.util
local ms = math3d.stack

local function move_position(p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

function util.move(obj, dx, dy, dz)
	local xdir, ydir, zdir = ms(obj.rotation, "bPPP")

	local eye = obj.position
	if dx then
		move_position(eye, xdir, dx)
	end
	if dy then
		move_position(eye, ydir, dy)
	end
	if dz then
		move_position(eye, zdir, dz)
	end
end

function util.rotate(obj, angle_xaxis, angle_yaxis)
	local rot = obj.rotation

	angle_xaxis = angle_xaxis or 0
	angle_yaxis = angle_yaxis or 0

	local rot_result = ms(rot, {angle_xaxis, angle_yaxis, 0, 0}, "+T")
	rot_result[1] = mu.limit(rot_result[1], -89.9, 89.9)	-- only yaw angle should limit in [-90, 90]
	ms(rot, rot_result, "=")
end

return util