local ltask = require "ltask"
ltask.uniqueservice("world", ...)

local ServiceWindow = ltask.queryservice "window"
ltask.call(ServiceWindow, "init")
ltask.call(ServiceWindow, "wait")
