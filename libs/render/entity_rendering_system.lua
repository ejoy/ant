local ecs = ...
local world = ecs.world

local ru = require "render.util"
local bgfx = require "bgfx"

local draw_entity_sys = ecs.system "entity_rendering"

draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "camera_controller"
draw_entity_sys.dependby "end_frame"

draw_entity_sys.singleton "math_stack"

function draw_entity_sys:update()
    local main_viewid = 0
    bgfx.touch(main_viewid)
    ru.draw_scene(main_viewid, world, self.math_stack)    
end