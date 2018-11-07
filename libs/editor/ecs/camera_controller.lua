local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.camera.camera_component"
ecs.import "render.components.general"
ecs.import "inputmgr.message_system"
ecs.import "timer.timer"

local mu = require "math.util"
local cu = require "render.components.util"

local point2d = require "math.point2d"

local camera_util = require "render.camera.util"

local action_type = { 
	FORWARD = false, BACKWARD = false,
	LEFT = false, RIGHT = false,
	UPWARD = false, DOWNWARD = false,
	LEFTROT = false, RIGHTROT = false,
	ROTX = false, ROTY = false
}
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"
camera_controller_system.singleton "timer"

camera_controller_system.depend "message_system"
camera_controller_system.depend "camera_init"

function camera_controller_system:init()
	local ms = self.math_stack
	local camera = world:first_entity("main_camera")

	local move_speed = 1
	local message = {}

    local last_xy
	local button_status = {}
	-- luacheck: ignore self
	-- luacheck: ignore status
    function message:button(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
    end

	function message:motion(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
				camera_util.rotate(ms, camera, delta.x, delta.y)
			end 
		end

		last_xy = xy
	end

	local action_name_mappers = {
		-- right button
		r_a = "LEFT", r_d = "RIGHT",
		r_w = "FORWARD", r_s = "BACKWARD",
		r_c = "DOWNWARD", r_f = "UPWARD",		
		r_q = "LEFTROT", r_e = "RIGHTROT",
	}

	function message:keypress(c, p, status)
		if c == nil then return end
		
		local name = nil
		if button_status.RIGHT then
			name = 'r_'
		elseif button_status.LEFT then
			name = 'l_'
		end

		if name then
			name = name .. c:lower()
			local t = action_name_mappers[name]
			if t then
				action_type[t] = p
			end	
		end		
	end

	self.message.observers:add(message)
end
-- make movement smooth 
function camera_controller_system:update()

	local camera = world:first_entity("main_camera")
	if camera then
		local ms = self.math_stack
		local deltaTime = self.timer.delta
		local step = 0.05
		local dx, dy, dz = 0, 0, 0
		if action_type.FORWARD then 
			dz = step
		elseif action_type.BACKWARD then
			dz = -step
		end

		if action_type.LEFT then 
			dx = -step			
		elseif action_type.RIGHT then 
			dx = step
		end

		if action_type.UPWARD then
			dy = step
		elseif action_type.DOWNWARD then
			dy = -step
		end

		if action_type.LEFTROT then 
			camera_util.rotate(ms, camera, -step * deltaTime , 0)
		elseif action_type.RIGHTROT then 
			camera_util.rotate(ms, camera,  step * deltaTime, 0)
		end 

		camera_util.move(ms, camera, dx*deltaTime, dy*deltaTime, dz*deltaTime)
	end 
end 	

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
			local scale = e.scale
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
			ms(camera.rotation, new_camera_rotation, "=")
			ms(camera.position, newpos, "=")
		end
	end
end
--@]