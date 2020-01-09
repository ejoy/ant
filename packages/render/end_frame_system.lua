local ecs = ...
local world = ecs.world

local math3d 	= require "math3d"
local math		= import_package "ant.math"
local ms 		= math.stack

ecs.component "frame_stat"
	.frame_num "int"
	.bgfx_frames "int"

ecs.singleton "frame_stat" {
	frame_num 	= 0,
	bgfx_frames = -1,
}

local end_frame_sys = ecs.system "end_frame"
end_frame_sys.require_singleton "frame_stat"

function end_frame_sys:end_frame()
	local stat = world:singleton "frame_stat"
	stat.frame_num = stat.frame_num + 1
	math3d.reset(ms)
end
