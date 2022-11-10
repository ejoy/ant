local ecs   = ...
local world = ecs.world
local w     = world.w

local iterrain  = ecs.import.interface "ant.terrain|iterrain"
local terrain_test_sys = ecs.system "terrain_test_system"

function terrain_test_sys:init()
    -- 32 32 means terrain's width and height
    -- terrain should be generated in initial stage
    iterrain.gen_terrain_field(32, 32)
end

-- world coordinate x
-- world coordinate y 
-- road's type (I L T U X)
-- road's dirction (N E S W)
local create_list = {
    {1, 1, "L", "W"},
    {2, 1, "I", "E"},
    {3, 1, "L", "N"},
    {1, 2, "I", "N"},
    {3, 2, "I", "N"},
    {1, 3, "L", "S"},
    {2, 3, "I", "E"},
    {3, 3, "L", "E"},
    {7, 1, "I", "N"},
    {8, 1, "I", "N"},
    {9, 1, "I", "N"},
}

local mark = false

function terrain_test_sys:data_changed()
    if mark == false then
        -- create/update/delete road need a create/update/delete list,
        -- and it should be executed once.
        -- otherwise, vertex buffer will overflow
        iterrain.create_roadnet_entity(create_list)
        mark = true
    end
end