local ecs = ...
local world = ecs.world
local schema = world.schema

local bgfx = require "bgfx"

schema:userdata "frame_stat"
local stat = ecs.component "frame_stat"
function stat:init()
	return {
		frame_num = 0
	}
end

schema:userdata "post_end_frame_jobs"
local post_jobs = ecs.component "post_end_frame_jobs"
function post_jobs:init()
	self.jobs = {}
end

local end_frame_sys = ecs.system "end_frame"

end_frame_sys.singleton "frame_stat"

local math3d = require "math3d"
local math = import_package "ant.math"
local ms = math.stack

function end_frame_sys:update() 
    local stat = self.frame_stat
	stat.frame_num = bgfx.frame()
	
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