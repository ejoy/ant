local ltask = require "ltask"
local fs = require "filesystem"
local ServiceAudio

local m = {}

function m.init()
	ServiceAudio = ltask.uniqueservice "ant.audio|audio"
	ltask.send(ServiceAudio, "worker_init")
end

function m.load(banks)
    for i, f in ipairs(banks) do
        banks[i] = fs.path(f):localpath():string()
    end
	ltask.send(ServiceAudio, "load", banks)
end

function m.play(event_name)
	ltask.send(ServiceAudio, "play", event_name)
end

function m.play_background(event_name)
	ltask.send(ServiceAudio, "play_background", event_name)
end

function m.stop_background(fadeout)
	ltask.send(ServiceAudio, "stop_background", fadeout)
end

function m.frame()
	ltask.send(ServiceAudio, "worker_frame")
end

return m
