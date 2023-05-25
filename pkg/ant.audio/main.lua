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

local cmdqueue = {}

function m.play(event_name)
	cmdqueue[#cmdqueue+1] = { "play", event_name }
end

function m.play_background(event_name)
	cmdqueue[#cmdqueue+1] = { "play_background", event_name }
end

function m.stop_background(fadeout)
	cmdqueue[#cmdqueue+1] = { "stop_background", fadeout }
end

function m.frame()
	if #cmdqueue > 0 then
		ltask.send(ServiceAudio, "worker_frame", cmdqueue)
		cmdqueue = {}
	else
		ltask.send(ServiceAudio, "worker_frame")
	end
end

return m
