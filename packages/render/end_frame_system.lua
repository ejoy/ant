local ecs = ...

local math3d 	= require "math3d"
local math		= import_package "ant.math"
local ms 		= math.stack

local frame_stat = ecs.singleton "frame_stat"
function frame_stat.init()
	return {
		frame_num 	= 0,
		bgfx_frames = -1,
	}
end

ecs.singleton "post_end_frame_jobs"

local end_frame_sys = ecs.system "end_frame"
end_frame_sys.singleton "frame_stat"
end_frame_sys.singleton "post_end_frame_jobs"

function end_frame_sys:end_frame()
    local stat = self.frame_stat
	stat.frame_num = stat.frame_num + 1
	math3d.reset(ms)
end

function end_frame_sys:final()
	if next(self.post_end_frame_jobs) then
		for _, job in ipairs(self.post_end_frame_jobs) do
			job()
		end
		self.post_end_frame_jobs = {}
	end
end