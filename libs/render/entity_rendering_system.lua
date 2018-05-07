local ecs = ...
local world = ecs.world

local ru = require "render.util"
local bgfx = require "bgfx"

local draw_entity_sys = ecs.system "entity_rendering"

--draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "camera_controller"
draw_entity_sys.depend "primitive_filter_system"
draw_entity_sys.dependby "end_frame"

draw_entity_sys.singleton "math_stack"
draw_entity_sys.singleton "primitive_filter"

function draw_entity_sys:update()
    local camera = world:first_entity("main_camera")
    local main_viewid = camera.viewid.id
    bgfx.touch(main_viewid)
    local ms = self.math_stack
    local result = self.primitive_filter.result
    for _, prim in ipairs(result) do
        local srt = prim.srt
        local mat = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
        ru.draw_primitive(main_viewid, prim, mat)
    end
end