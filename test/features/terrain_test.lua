local ecs   = ...
local world = ecs.world
local w     = world.w

local iterrain  = ecs.interface "iterrain"
local terrain_test_sys = ecs.system "terrain_test_system"

function terrain_test_sys:init()
    iterrain.gen_terrain_field(32, 32)
    iterrain.create_roadnet_entity(1, 1, "L", "W")
    iterrain.create_roadnet_entity(2, 1, "I", "E")
    iterrain.create_roadnet_entity(3, 1, "L", "N")
    iterrain.create_roadnet_entity(1, 2, "I", "N")
    iterrain.create_roadnet_entity(3, 2, "I", "N")
    iterrain.create_roadnet_entity(1, 3, "L", "S")
    iterrain.create_roadnet_entity(2, 3, "I", "E")
    iterrain.create_roadnet_entity(3, 3, "L", "E") 
    iterrain.create_roadnet_entity(6, 6, "L", "N") 
    iterrain.create_terrain_entity()
end
