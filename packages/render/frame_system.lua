local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	= require "math3d"
local start_frame_sys = ecs.system "start_frame_system"

function start_frame_sys:start_frame()

	math3d.reset()

	-- world:print_cpu_stat()
	-- world:reset_cpu_stat()
end
