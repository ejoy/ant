local ltask = require "ltask"
local config = ...

if config.boot then
	ltask.spawn(config.boot, config)
end

local SERVICE_ROOT <const> = 1

ltask.fork(function ()
	ltask.call(SERVICE_ROOT, "worker_bind", "ant.window|window", 0)
	ltask.uniqueservice "ant.hwi|bgfx"
end)

ltask.call(SERVICE_ROOT, "worker_bind", "ant.hwi|bgfx", 1)
local ServiceWindow = ltask.uniqueservice("ant.window|window", ...)
ltask.call(ServiceWindow, "wait")
