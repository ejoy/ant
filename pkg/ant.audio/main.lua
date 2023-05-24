local fs = require "filesystem"

local ltask = require "ltask"
local ServiceAudio = ltask.uniqueservice "ant.audio|audio"

local m = {}

function m.load_bank(filename)
	local localf = fs.path(filename):localpath():string()
	ltask.call(ServiceAudio, "load_bank", localf)
end

function m.play(event_name)
	ltask.call(ServiceAudio, "play", event_name)
end

return m
