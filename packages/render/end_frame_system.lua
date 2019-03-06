local ecs = ...

local bgfx = require "bgfx"

local frame_stat = ecs.singleton "frame_stat"
function frame_stat:init()
	return {
		frame_num = 0,
		bgfx_frames = -1,
	}
end

local post_end_frame_jobs = ecs.singleton "post_end_frame_jobs"
function post_end_frame_jobs:init()
	return {
		jobs = {}
	}
end

local end_frame_sys = ecs.system "end_frame"

end_frame_sys.singleton "frame_stat"

local math3d = require "math3d"
local math = import_package "ant.math"
local ms = math.stack

function end_frame_sys:update() 
    local stat = self.frame_stat
	stat.frame_num = stat.frame_num + 1
	stat.bgfx_frames = bgfx.frame()
	
	math3d.reset(ms)	
end

local post_end_frame = ecs.system "post_end_frame"
post_end_frame.singleton "post_end_frame_jobs"

post_end_frame.depend "end_frame"

function post_end_frame:update()
	local jobs = self.post_end_frame_jobs.jobs
	for _, job in ipairs(jobs) do
		job()
	end
	self.post_end_frame_jobs.jobs = {}
end