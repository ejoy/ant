local manager = require "font.manager"
local fontutil = require "font.util"
local vfs = require "vfs"
local fastio = require "fastio"
local serialization = require "bee.serialization"

local function readall_v(path)
    local mem = vfs.read(path)
    if not mem then
        error(("file '%s' not found"):format(path))
    end
    return mem
end

local function readall(path)
    local mem, symbol = vfs.read(path)
    if not mem then
        error(("file '%s' not found"):format(path))
    end
    return fastio.wrap(mem), "@"..symbol
end

local m = {}

local instance = manager.init(readall "/pkg/ant.hwi/font/manager.lua")
local lfont = require "font" (instance)

local imported = {}

function m.instance()
    if not instance then
        return
    end
    return serialization.lightuserdata(instance)
end

function m.import(path)
    if imported[path] then
        return
    end
    imported[path] = true
    if path:sub(1, 1) == "/" then
        lfont.import(readall_v(path))
    else
        local memory = fontutil.systemfont(path) or error(("`read system font `%s` failed."):format(path))
        lfont.import(memory)
    end
end

function m.shutdown()
    manager.shutdown(instance)
    instance = nil
end

return m
