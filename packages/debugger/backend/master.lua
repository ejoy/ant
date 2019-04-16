local mgr = require 'backend.master.mgr'

local m = {}

function m.init(io)
    mgr.init(io)
    return true
end

function m.update()
    while true do
        local quit = mgr.runIdle()
        if quit then
            break
        end
    end
end

return m
