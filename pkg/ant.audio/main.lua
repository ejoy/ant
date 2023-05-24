local ltask = require "ltask"
local ServiceAudio

local m = {}

function m.init(banks)
	if banks ~= nil then
		ServiceAudio = ltask.uniqueservice("ant.audio|audio", banks)
	else
		ServiceAudio = ltask.queryservice "ant.audio|audio"
	end
end

function m.play(event_name)
	ltask.call(ServiceAudio, "play", event_name)
end

return m
