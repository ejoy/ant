local ecs = ...
local world = ecs.world

local mu = require "math.util"
local cu = require "render.components.util"
local point2d = require "math.point2d"
local camera_util = require "render.camera.util"
local math3d = require "math3d"

local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "iup_message"
camera_controller_system.depend "camera_init"

local function camera_move_position(ms, p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

function camera_move(ms, rotation, position, dx, dy, dz)
	local xdir, ydir, zdir = ms(rotation, "bPPP")
	local eye = position
	camera_move_position(ms, eye, xdir, dx)
	camera_move_position(ms, eye, ydir, dy)
	camera_move_position(ms, eye, zdir, dz)
end

function camera_controller_system:init()
	local ms = self.math_stack
	local camera = world:first_entity("main_camera")

	--local mathstack = math3d.new()
	--local mt = debug.getmetatable(camera.position.v)
	--function mt:__debugger_extand()
	--	local t = mathstack(self, "T")
	--	local ret = {}
	--	--LINEAR_TYPE_MAT
	--	--LINEAR_TYPE_VEC4
	--	if t.type == 1 then
	--		for i, v in ipairs(t) do
	--			local name = ('[%d]'):format(i)
	--			ret[#ret+1] = name
	--			ret[name] = v
	--		end
	--		return ret
	--	end
	--	--LINEAR_TYPE_QUAT
	--	--LINEAR_TYPE_NUM
	--	--LINEAR_TYPE_EULER
	--end

	local target = math3d.ref "vector"
    ms(target, {0, 0, 0, 1}, "=")
    ms(camera.position.v, {5, 5, -5, 1}, "=")
	ms(camera.rotation.v, target, camera.position.v, "-D=")

	local move_speed = 1
	local message = {}

    local last_xy
    function message:button(btn, p, x, y, status)
        last_xy = point2d(x, y)
    end

	function message:motion(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				camera_move(ms, camera.rotation.v, target, -delta.x, delta.y, 0)
				camera_move(ms, camera.rotation.v, camera.position.v, -delta.x, delta.y, 0)
			elseif status.LEFT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				local distance = math.sqrt(ms(camera.position.v, target, camera.position.v, "-1.T")[1])
				camera_move(ms, camera.rotation.v, camera.position.v, -delta.x, delta.y, 0)
				ms(camera.rotation.v, target, camera.position.v, "-D=")
				ms(camera.position.v, target, {-distance}, camera.rotation.v, "dn*+=")
			end
		end
		last_xy = xy
	end

	function message:wheel(delta, x, y, status)
		camera_move(ms, camera.rotation.v, camera.position.v, 0, 0, delta * move_speed)
	end
	self.message_component.msg_observers:add(message)
end
