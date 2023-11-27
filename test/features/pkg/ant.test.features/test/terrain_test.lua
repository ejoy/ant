local ecs   = ...
local world = ecs.world
local w     = world.w

local terrain_test_sys = ecs.system "terrain_test_system"

function terrain_test_sys:init_world()
    -- 32 32 means terrain's width and height
    -- 10 means origin's x and z offset to left-bottom dirction
    -- terrain should be generated in initial stage
    --iterrain.gen_terrain_field(256, 256, 0)
end

-- world coordinate x
-- world coordinate y
-- layers: road/mark/road and mark
--         road: type(1~3) shape(I L T U X O) dir(N E S W)
--         mark: type(1~2) shape(U I O) dir(N E S W)     
local create_list = {
    -- single road layer:road1 road2 road3
    {
        x = 0, y = 0,
        layers =
        {
            road =
            {
                type  = "1",
                shape = "I",
                dir   = "N"
            }
        }
    },
    {
        x = 6, y = 1,
        layers =
        {
            road =
            {
                type  = "1",
                shape = "I",
                dir   = "N"
            }
        }
    },
    {
        x = 7, y = 1,
        layers =
        {
            road =
            {
                type  = "2",
                shape = "I",
                dir   = "N"
            }
        }
    },
    {
        x = 8, y = 1,
        layers =
        {
            road =
            {
                type  = "3",
                shape = "I",
                dir   = "N"
            }
        }
    },
    
    --single mark layer:mark1 mark2
    {
        x = 2, y = 2,
        layers =
        {
            mark =
            {
                type  = "1",
                shape = "U",
                dir   = "E"
            }
        }
    },
    {
        x = 3, y = 2,
        layers =
        {
            mark =
            {
                type  = "1",
                shape = "U",
                dir   = "W"
            }
        }
    },
    {
        x = 4, y = 2,
        layers =
        {
            mark =
            {
                type  = "1",
                shape = "O",
                dir   = "N"
            }
        }
    },
    {
        x = 2, y = 1,
        layers =
        {
            mark =
            {
                type  = "2",
                shape = "U",
                dir   = "E"
            }
        }
    },
    {
        x = 3, y = 1,
        layers =
        {
            mark =
            {
                type  = "2",
                shape = "I",
                dir   = "W"
            }
        }
    },
    {
        x = 4, y = 1,
        layers =
        {
            mark =
            {
                type  = "2",
                shape = "U",
                dir   = "W"
            }
        }
    },

    -- multiple layer: road1 road2 road3 and mark1 mark2
    {
        
        x = 1, y = 1,
        layers =
        {
            road =
            {
                type  = "1",
                shape = "I",
                dir   = "N"                
            },
            mark =
            {
                type  = "1",
                shape = "I",
                dir   = "N"
            }
        }
    },
    {
        x = 1, y = 2,
        layers =
        {
            road =
            {
                type  = "2",
                shape = "L",
                dir   = "N"                
            },
            mark =
            {
                type  = "2",
                shape = "O",
                dir   = "S"
            }
        }
    },
}

local mark = false

function terrain_test_sys:data_changed()
--[[     if mark == false then
        -- create/update/delete road need a create/update/delete list,
        -- and it should be executed once.
        -- otherwise, vertex buffer will overflow
        iterrain.create_roadnet_entity(create_list)
        mark = true
    end
    iterrain.is_stone_mountain(46, 0) ]]
end