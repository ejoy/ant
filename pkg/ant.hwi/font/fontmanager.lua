local manager = require "font.manager"
local fontutil = require "font.util"
local aio = import_package "ant.io"

local m = {}

local instance, instance_ptr = manager.init(aio.readall "/pkg/ant.hwi/font/manager.lua")
local lfont = require "font" (instance_ptr)

local imported = {}

function m.instance()
    return instance_ptr
end

function m.import(path)
    if imported[path] then
        return
    end
    imported[path] = true
    if path:sub(1, 1) == "/" then
        lfont.import(aio.readall_v(path))
    else
        local memory = fontutil.systemfont(path) or error(("`read system font `%s` failed."):format(path))
        lfont.import(memory)
    end
end

function m.shutdown()
    manager.shutdown(instance)
    instance = nil
    instance_ptr = nil
end

return m
