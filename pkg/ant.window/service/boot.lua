local ltask = require "ltask"

local ServiceWindow = ltask.uniqueservice("ant.window|window", ...)
ltask.call(ServiceWindow, "wait")
