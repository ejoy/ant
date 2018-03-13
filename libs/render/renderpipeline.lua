local ecs = ...
local world = ecs.world
local ru = require "render.render_util"
local cu = require "render.components.util"
local bgfx = require "bgfx"

local world_mat_comp = ecs.component "worldmat_comp" {
    mat = {type = "matrix"}
}

--[@
local auto_rotate_worldmat_sys = ecs.system "rotate_worldmat_system"
auto_rotate_worldmat_sys.singleton "math_stack"

local time = 0
function auto_rotate_worldmat_sys:update()
    local speed = 1
    time = time + speed

    ru.foreach_comp(world, {"worldmat_comp"},
    function (entity)
        --entity.world_mat_comp.mat = entity.math_stack(entity.world_mat_comp, {time}, "*M") 
    end)
end
--@]

--[@
local rpl_system = ecs.system "render_pipeline"

rpl_system.depend "add_entities_system"
rpl_system.depend "camera_system"
rpl_system.depend "viewport_system"

rpl_system.singleton "math_stack"

function rpl_system:init()
end

function rpl_system:update() 
    bgfx.touch(0)

    ru.foreach_comp(world, cu.get_sceneobj_compoent_names(),
    function (entity)
        local ms = self.math_stack
        local mat = ms({type="srt", s=entity.scale.v, r=entity.direction.v, t=entity.position.v}, "m")
        ru.draw_entity(entity, mat)
    end)

    bgfx.frame()
end

--@]