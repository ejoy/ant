
local bgfx = require "bgfx"
local lfont = require "font" (bgfx.fontmanager())
local m = {}

function m.import(filename)
    return lfont.import(filename:localpath():string())
end

return m
