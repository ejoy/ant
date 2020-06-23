local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local iwd = world:interface "ant.render|iwidget_drawer"
local m = ecs.system 'geo_system'
function m:draw_geo()
    -- local shape = {math3d.vector(0,0,0), math3d.vector(1,1,1)}
    -- iwd.draw_lines(shape, math3d.matrix {s = 1.0, t = {0.0, 0.0, 0.0, 1}}, 0xff0000ff)
end