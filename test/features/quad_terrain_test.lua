local ecs   = ...
local world = ecs.world
local w     = world.w


local quad_terrain_test_sys = ecs.system "quad_terrain_test_system"

local function generate_terrain_fields(w, h)
    local quad_types<const> = {
        "none", "grass", "dust"
    }

    local fields = {}
    for ih=1, h do
        for iw=1, w do
            local which = math.random(1, 3)
            fields[#fields+1] = {
                type = quad_types[which]
            }
        end
    end

    return fields
end

function quad_terrain_test_sys:init()
    local terrain_fields = generate_terrain_fields(16, 16)
    ecs.create_entity{
        policy = {
            "ant.terrain|quad_terrain",
            "ant.general|name",
        },
        data = {
            name = "quad_terrain_test",
            quad_terrain = {
                terrain_field = terrain_fields,
                material = "/pkg/ant.test.features/assets/quad_terrain.material"
            }
        }
    }
end