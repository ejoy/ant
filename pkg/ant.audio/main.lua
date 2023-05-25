local ltask = require "ltask"
local ServiceAudio

local m = {}

function m.init(banks)
	if banks ~= nil then
		ServiceAudio = ltask.uniqueservice("ant.audio|audio", banks)
	else
		ServiceAudio = ltask.queryservice "ant.audio|audio"
	end
	ltask.send(ServiceAudio, "worker_init")
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
