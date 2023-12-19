local ltask = require "ltask"

ltask.fork(function ()
    ltask.uniqueservice("ant.rmlui|rmlui", ltask.self())
end)

ltask.call(ltask.queryservice "imgui|imgui", "wait")
