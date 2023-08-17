
local bgfx = require "bgfx"
local fs = require "filesystem"
local lfont = require "font" (bgfx.fontmanager())
local m = {}

function m.import(path)
    lfont.import(fs.path(path):localpath():string())
end

return m
