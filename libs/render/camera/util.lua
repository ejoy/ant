local util = {}; util.__index = util

local mu = require "math.util"
local ms = require "math.stack"

local function move_position(p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

function util.move(camera, dx, dy, dz)
	local xdir, ydir, zdir = ms(camera.rotation, "bPPP")

	local eye = camera.position
	move_position(eye, xdir, dx)
	move_position(eye, ydir, dy)
	move_position(eye, zdir, dz)

	-- if c == "a" or c == "A" then
	-- 	move_position(eye, xdir, move_step)
	-- elseif c == "d" or c == "D" then					
	-- 	move_position(eye, xdir, -move_step)
	-- elseif c == "w" or c == "W" then					
	-- 	move_position(eye, zdir, move_step)
	-- elseif c == "s" or c == "S" then					
	-- 	move_position(eye, zdir, -move_step)
	-- elseif c == "q" or c == "Q" then
	-- 	move_position(eye, ydir, move_step)
	-- elseif c == "e" or c == "E" then
	-- 	move_position(eye, ydir, -move_step)					
	-- end
end

function util.rotate(camera, dx, dy)
	local rot = camera.rotation

	local rot_result = ms(rot, {dy, dx, 0, 0}, "+T")

	rot_result[1] = mu.limit(rot_result[1], -89.9, 89.9)
	ms(rot, rot_result, "=")
end

return util