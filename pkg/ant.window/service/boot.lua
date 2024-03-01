local ltask = require "ltask"
local config = ...

if config.boot then
	ltask.spawn(config.boot, config)
end

local ServiceWindow = ltask.uniqueservice("ant.window|window", ...)
ltask.call(ServiceWindow, "wait")
