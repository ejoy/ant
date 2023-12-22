local ltask = require "ltask"

local ServiceWindow = ltask.queryservice "ant.window|window"
ltask.call(ServiceWindow, "start", ...)
local ServiceWorld = ltask.uniqueservice("ant.window|world", ...)
ltask.call(ServiceWorld, "wait")
