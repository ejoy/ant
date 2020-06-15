local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local iwd = world:interface "ant.render|iwidget_drawer"
local m = ecs.system 'geo_system'
function m:draw_geo()
    local srt2 = world.component "srt" {s = {1.0}, t = {0.0, 1.5, 0.0, 1}}
    local shape = {math3d.vector(0,0,0), math3d.vector(1,1,1)}
    iwd.draw_lines(shape, srt2)
end