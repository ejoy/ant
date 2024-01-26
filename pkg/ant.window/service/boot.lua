local ltask = require "ltask"

local ServiceWorld = ltask.queryservice "ant.window|world"
ltask.call(ServiceWorld, "wait")
