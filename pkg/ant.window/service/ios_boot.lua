local ltask = require "ltask"

local ServiceWorld = ltask.uniqueservice("ant.window|world", ...)
ltask.call(ServiceWorld, "wait")
