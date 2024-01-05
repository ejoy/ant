local manager = require "font.manager"
local fontutil = require "font.util"
local vfs = require "vfs"

local fontvm = [[
    local dbg = assert(loadfile '/engine/debugger.lua')()
    if dbg then
        dbg:event("setThreadName", "Thread: Font")
        dbg:event "wait"
    end
    dofile "/pkg/ant.hwi/font/manager.lua"
]]

local m = {}

local instance = manager.init(fontvm)
local lfont = require "font" (instance)

local imported = {}

function m.instance()
    return instance
end

function m.import(path)
    if imported[path] then
        return
    end
    imported[path] = true
    if path:sub(1, 1) == "/" then
        local memory = vfs.read(path) or error(("`read font `%s` failed."):format(path))
        lfont.import(memory)
    else
        local memory = fontutil.systemfont(path) or error(("`read system font `%s` failed."):format(path))
        lfont.import(memory)
    end
end

function m.shutdown()
    manager.shutdown()
    instance = nil
end

return m
