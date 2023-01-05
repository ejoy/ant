local ecs   = ...
local world = ecs.world
local w     = world.w

local iterrain  = ecs.import.interface "ant.terrain|iterrain"
local terrain_test_sys = ecs.system "terrain_test_system"

function terrain_test_sys:init_world()
    -- 32 32 means terrain's width and height
    -- 10 means origin's x and z offset to left-bottom dirction
    -- terrain should be generated in initial stage
    iterrain.gen_terrain_field(32, 32, 10, 10)
end

-- world coordinate x
-- world coordinate y
-- road's type (Road Red White) 
-- road's shape 
    --Road  (I L T U X O)
    --Red   (U I O)
    --White (U I O)
-- road's dirction (N E S W)
local create_list = {
    {1, 2, "Red", "U", "S"},
    {2, 2, "Red", "U", "E"},
    {3, 2, "Red", "U", "W"},
    {4, 2, "Red", "O", "N"},
    {1, 1, "Red", "U", "N"},
    {2, 1, "White", "U", "E"},
    {3, 1, "White", "I", "W"},
    {4, 1, "White", "U", "W"},
    {7, 1, "Road", "I", "N"},
    {8, 1, "Road", "I", "N"},
    {9, 1, "Road", "I", "N"},
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