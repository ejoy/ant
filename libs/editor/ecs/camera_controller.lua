local ecs = ...
local world = ecs.world

local mu = require "math.util"
local cu = require "render.components.util"

local point2d = require "math.point2d"

local camera_util = require "render.camera.util"

-- local function calc_rotate_angle_from_view_direction(ms, vr)
-- 	-- the default view direction is (0, 0, 1, 0)
-- 	local dir = ms(vr, "nT")
-- 	assert(dir.type == 1 or dir.type == 2)	-- 1 for vec4, 2 for vec3

-- 	local x, y, z = dir[1], dir[2], dir[3]
-- 	local pitch = -math.asin(y)
-- 	local yaw = z ~= 0 and math.atan2(x, z) or 0

-- 	local function to_angle(rad)
-- 		return rad * (180 / 3.1415926)
-- 	end

-- 	return to_angle(pitch), to_angle(yaw)
-- end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	local ms = self.math_stack
	local camera = world:first_entity("main_camera")

	local message = {}

    local last_xy
    local button_status = {}
    function message:button(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
    end

	function message:motion(x, y, status)
		local xy = point2d(x, y)
		if last_xy then			
			--if (status.LEFT or status.RIGHT) and last_xy then
			if status.RIGHT then
				local speed = message.move_speed * 0.1
				local delta = (xy - last_xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
				camera_util.rotate(ms, camera, delta.x, delta.y)
			end
		end

		last_xy = xy
	end

	function message:keypress(c, p, status)
		if c == nil then return end
		
		do
			if p then
				local ms = message.ms

				local move_step = message.move_speed
				local rot = camera.rotation.v
				local eye = camera.position.v

				local rightbtn_down = button_status.RIGHT
				local leftbtn_down = button_status.LEFT

				local nomouse_down = not (rightbtn_down or leftbtn_down)
				if nomouse_down and (c == "r" or c == "R") then
					ms(	eye, {0, 0, -10}, "=")
					ms( rot, {0, 0, 0}, "=")
					return 
				end

				if rightbtn_down then					
					local dx, dy, dz = 0, 0, 0			

					if c == "a" or c == "A" then					
						dx = -move_step
					elseif c == "d" or c == "D" then					
						dx = move_step
					elseif c == "w" or c == "W" then					
						dz = move_step
					elseif c == "s" or c == "S" then					
						dz = -move_step
					elseif c == "q" or c == "Q" then
						dy = -move_step
					 elseif c == "e" or c == "E" then
						dy = move_step
					end

					camera_util.move(ms, camera, dx, dy, dz)
				end
			end
		end
	end

	self.message_component.msg_observers:add(message)
	message.cb = {}
	message.msg_comp = self.message_component
	message.ms = self.math_stack
	message.move_speed = 1
end

-- function camera_controller_system:update()
-- 	local camera = world:first_entity("main_camera")
-- 	if camera then
-- 		local cs = self.control_state.state
-- 		if cs == "camera" or cs == "default" then
-- 			for _, cb in pairs(message.cb) do
-- 				cb(camera)
-- 			end
-- 		end
-- 	end
	
-- 	message.cb = {}
-- end

function camera_controller_system.notify:focus_selected_obj(objects)
	--only using first obj
	local eid = objects[1]
	local e = world[eid]

	if cu.is_entity_visible(e) then
		local mesh = e.mesh
		if mesh then
			local handle = mesh.assetinfo.handle
			if nil == handle.sphere then
				return 
			end

			local function to_sphere(s)
				return { 
					center = {s[1], s[2], s[3]}, 
					radius = s[4]
				}
			end

			--[@	transform sphere
			local ms = self.math_stack
			local sphere = to_sphere(handle.sphere)
			local srtWS = mu.srt_from_entity(ms, e)
			
			local centerWS = ms(sphere.center, srtWS, "*T")
			sphere.center = centerWS

			local camera = world:first_entity("main_camera")
			local scale = e.scale.v
			local s = ms(scale, "T")
			local smax = math.max(s[1], s[2], s[3])			
			sphere.radius = smax * sphere.radius
			--@]

			local new_camera_rotation = {45, -45, 0}
			--[[
				local cameradir = todir(new_camera_rotation)
				cameradir = inverse(normalize(cameradir))
				local newpos = sphere.center + cameradir * sphere.radius * 3
			]]

			local newpos = ms(sphere.center, {sphere.radius * 3}, new_camera_rotation, "dni*+P")
			ms(camera.rotation.v, new_camera_rotation, "=")
			ms(camera.position.v, newpos, "=")
		end
	end
end
--@]