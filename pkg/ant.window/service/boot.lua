local ltask = require "ltask"
local config = ...

if config.boot then
	ltask.spawn(config.boot, config)
end

ltask.uniqueservice "ant.hwi|bgfx"
local ServiceWindow = ltask.uniqueservice("ant.window|window", ...)
ltask.call(ServiceWindow, "wait")
