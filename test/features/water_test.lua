local ecs = ...
local world = ecs.world
local w = world.w

local water_test_sys = ecs.system "water_test_system"
function water_test_sys:init()
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.terrain|water",
            "ant.general|name",
        },
        data = {
            water = {
                grid_width = 1,
                grid_height = 1,
            },
            materal = "",
            state = "visible",
            scene = {
                srt = {},
            },
            reference = true,
        }
    }
end