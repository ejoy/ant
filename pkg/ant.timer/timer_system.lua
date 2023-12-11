local ecs = ...

local ltask = require "ltask"

local function gettime()
	local _, now = ltask.now()
	return now * 10
end

local previous
local delta
local pause

local time_sys = ecs.system "time_system"

function time_sys:init()
	previous = gettime()
	delta = 0
end

function time_sys:timer()
	if pause then
		delta = 0
		previous = gettime()
	else
		local now = gettime()
		delta = now - previous
		previous = now
	end
end

local m = {}

function m.delta()
	return delta
end

function m.pause()
	pause = true
end

function m.continue()
	pause = false
end

return m
