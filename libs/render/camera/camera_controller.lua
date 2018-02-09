local math3d = require "math3d"
local stack = math3d.new()

local camera_controller = {}

function camera_controller:move_along_direction(step, speed)
	speed = speed or 1
	local thestep = step * speed;

	camera_transform.eye = stack(camera_transform.direction, {thestep, thestep, thestep, 1}, "*P", -- direction * theStep =>stackTop
								 camera_transform.eye, "+M")	-- stackTop + eye
end

function camera_controller:move_horizontal_and_vertical(step, speed)
	speed = speed or 1

end

function camera_controller:rotate(step, speed)
	speed = speed or 1
	local theStep = step * speed

end

return camera_controller