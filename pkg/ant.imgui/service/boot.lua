local ltask = require "ltask"

ltask.fork(function ()
    local ServiceRmlUi = ltask.uniqueservice "ant.rmlui|rmlui"
    ltask.call(ServiceRmlUi, "initialize", ltask.self())
end)

ltask.call(ltask.queryservice "ant.imgui|imgui", "wait")
