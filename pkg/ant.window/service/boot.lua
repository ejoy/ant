local ltask = require "ltask"

ltask.fork(function ()
    ltask.uniqueservice "ant.rmlui|rmlui"
end)

local ServiceWorld = ltask.uniqueservice("ant.window|world", ...)
ltask.call(ServiceWorld, "wait")
