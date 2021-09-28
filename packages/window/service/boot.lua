local ltask = require "ltask"
ltask.uniqueservice("ant.window|world", ...)

local ServiceWindow = ltask.queryservice "ant.window|window"
ltask.call(ServiceWindow, "create_window")
ltask.call(ServiceWindow, "wait")
