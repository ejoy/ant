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
                unit = 1,
            },
            simplemesh = true,
            material = "/pkg/ant.resources/materials/water.material",
            state = "visible",
            scene = {
                srt = {s=10, t={-5, 0.0, -5}},
            },
            reference = true,
            name = "water_test",
        }
    }
end