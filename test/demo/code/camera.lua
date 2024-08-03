local camera = {}

local distance_speed <const> = 0.5
local rot_speed <const> = 2
local pan_speed <const> = 0.2

local mouse_lastx = 0
local mouse_lasty = 0

function camera.mouse_ctrl(btn, state, x, y)
	local camera_ctrl = ant.camera_ctrl
	if btn == "WHEEL" then
		camera_ctrl.delta.distance = - state * distance_speed
	elseif btn == "RIGHT" then
		if state == "DOWN" then
			mouse_lastx, mouse_lasty = x, y
		elseif state == "MOVE" then
			local delta_x = x - mouse_lastx
			local delta_y = y - mouse_lasty
			camera_ctrl.delta.yaw = delta_x * rot_speed / 4
			camera_ctrl.delta.pitch = delta_y * rot_speed / 4
			mouse_lastx, mouse_lasty = x, y
		end
	end
end

function camera.key_ctrl()
	local key_press = ant.key_press
	local camera_ctrl = ant.camera_ctrl
	if key_press.Q then
		camera_ctrl.delta.yaw = rot_speed
	elseif key_press.E then
		camera_ctrl.delta.yaw = -rot_speed
	end
	
	if key_press.W then
		camera_ctrl.delta.y = pan_speed
	elseif key_press.S then
		camera_ctrl.delta.y = -pan_speed
	end

	if key_press.A then
		camera_ctrl.delta.x = -pan_speed
	elseif key_press.D then
		camera_ctrl.delta.x = pan_speed
	end

	if key_press.Y then
		camera_ctrl.delta.pitch = -rot_speed
	elseif key_press.H then
		camera_ctrl.delta.pitch = rot_speed
	end
end

return camera