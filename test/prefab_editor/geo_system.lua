local ecs = ...
local world = ecs.world
local iwd = world:interface "ant.render|iwidget_drawer"
local m = ecs.system 'geo_system'
function m:draw_geo()
    local shape = {size = 1, origin = {0.0, 0.0, 0.0, 1.0}}
    local srt = world.component "srt" {s = {1.0}}
    --iwd.draw_box(shape, srt, 0xff0000ff)
    local srt2 = world.component "srt" {s = {1.0}, t = {0.0, 1.5, 0.0, 1}}
    iwd.draw_lines(shape, srt2)
end