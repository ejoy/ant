local ecs   = ...
local world = ecs.world
local w     = world.w

local iom   = ecs.require "ant.objcontroller|obj_motion"

local plt_sys = ecs.system "point_light_test_system"

function plt_sys.init_world()
    local pl_pos = {
        {  1, 0, 1},
        { -1, 0, 1},
        { -1, 0,-1},
        {  1, 0,-1},
        {  1, 2, 1},
        { -1, 2, 1},
        { -1, 2,-1},
        {  1, 2,-1},

        {  3, 0, 3},
        { -3, 0, 3},
        { -3, 0,-3},
        {  3, 0,-3},
        {  3, 2, 3},
        { -3, 2, 3},
        { -3, 2,-3},
        {  3, 2,-3},
    }

    for _, p in ipairs(pl_pos) do
        world:create_instance {
            prefab = "/pkg/ant.test.features/assets/entities/light_point.prefab",
            on_ready = function(pl)
                iom.set_position(pl.root, pl)
            end
        }
    end

    world:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/pbr_cube.prefab",
        on_ready = function (ce)
            iom.set_position(ce.root, {0, 0, 0, 1})
        end
    }
    
    world:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/light_directional.prefab",
    }
end