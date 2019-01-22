local ecs = ...

local world = ecs.world

local math3d = import_package "ant.math"
local ms = math3d.stack

local objutil = require "util"

local cc = ecs.system "character_controller"
cc.depend "objcontroller_system"
cc.singleton "timer"

local objctrller = require "objcontroller"

function cc:init()
	-- TODO: we need to control the character state machine after "state_machine" on animation is finished, 
	-- then let the state machine to control the charather
	local timer = self.timer

	objctrller.register {
		tigger = {jump = {{name="keyboard", key = " ", press=true, state={}}}}
	}

	local function move(value, x, y, z)
		local character = assert(world:first_entity("character"))
		
		local movespeed = character.character.movespeed
		local deltatime = timer.delta * 0.001 * value
		local delta_dis = movespeed * deltatime		
		if x then
			x = x * delta_dis			
		end
		if y then
			y = y * delta_dis			
		end

		if z then
			z = z * delta_dis			
		end
		objutil.move(character, x, y, z)		
	end

	objctrller.bind_constant("move_forward", function (event, value)
		move(value, nil, nil, 1)
	end)

	objctrller.bind_constant("move_backward", function (event, value)
		move(value, nil, nil, 1)
	end)

	objctrller.bind_constant("move_left", function (event, value)
		move(value, 1)
	end)

	objctrller.bind_constant("move_right", function (event, value)
		move(value, 1)
	end)

	objctrller.bind_tigger("jump", function (event, value)
		
	end)
end