
local bgfx = require "bgfx"
local fs = require "filesystem"
local lfont = require "font" (bgfx.fontmanager())
local m = {}

local loaded = {}

function m.import(path)
    local lpath = fs.path(path):localpath():string()
    if loaded[lpath] then
        return
    end
    lfont.import(lpath)
    loaded[lpath] = true
end

return m
