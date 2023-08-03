local manager = require "font.manager"

local fontvm; do
    if __ANT_RUNTIME__ then
        fontvm = [[dofile "/pkg/ant.hwi/font/manager.lua"]]
    else
        fontvm = (([[
            local dbg = assert(loadfile '/engine/debugger.lua')()
            if dbg then
                dbg:event("setThreadName", "Font thread")
                dbg:event "wait"
            end
            require "vfs"
            dofile "/pkg/ant.hwi/font/manager.lua"
        ]]):format(package.cpath))
    end
end

local m = {}

local instance = manager.init(fontvm)

function m.instance()
    return instance
end

function m.shutdown()
    manager.shutdown()
    instance = nil
end

return m
