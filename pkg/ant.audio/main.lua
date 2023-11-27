local ltask = require "ltask"
local ServiceAudio

local m = {}

function m.load(banks)
	if not ServiceAudio then
		ServiceAudio = ltask.uniqueservice "ant.audio|audio"
		ltask.send(ServiceAudio, "worker_init")
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
		if not ServiceAudio then
			ServiceAudio = ltask.queryservice "ant.audio|audio"
			ltask.send(ServiceAudio, "worker_init")
		end
		ltask.send(ServiceAudio, "worker_frame", cmdqueue)
		cmdqueue = {}
	else
		if not ServiceAudio then
			return
		end
		ltask.send(ServiceAudio, "worker_frame")
	end
end

return m
