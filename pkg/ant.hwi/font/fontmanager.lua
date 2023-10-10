local manager = require "font.manager"

local fontvm = [[
    local dbg = assert(loadfile '/engine/debugger.lua')()
    if dbg then
        dbg:event("setThreadName", "Thread: Font")
        --dbg:event "wait"
    end
    dofile "/pkg/ant.hwi/font/manager.lua"
]]

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
