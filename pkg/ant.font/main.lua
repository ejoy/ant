
local bgfx = require "bgfx"
local aio = import_package "ant.io"
local lfont = require "font" (bgfx.fontmanager())
local m = {}

local loaded = {}

function m.import(path)
    if loaded[path] then
        return
    end
    lfont.import(path, aio.readall_v(path))
    loaded[path] = true
end

return m
