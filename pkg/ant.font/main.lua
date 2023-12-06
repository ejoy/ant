
local bgfx = require "bgfx"
local m = {}

function m.import(path)
    bgfx.fontimport(path)
end

return m
