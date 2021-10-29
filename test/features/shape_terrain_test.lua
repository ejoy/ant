local ecs   = ...
local world = ecs.world
local w     = world.w


local shape_terrain_test_sys = ecs.system "shape_terrain_test_system"

local function generate_terrain_fields(w, h)
    local quad_types<const> = {
        "none", "grass", "dust"
    }

    -- local fields = {}
    -- for ih=1, h do
    --     for iw=1, w do
    --         local which = math.random(1, 3)
    --         local height = math.random() * 0.05
    --         fields[#fields+1] = {
    --             type    = quad_types[which],
    --             height  = height,
    --         }
    --     end
    -- end

    -- return fields
    local function build(stream)
        local fields = {}
        for _, t in ipairs(stream) do
            fields[#fields+1] = {
                type = quad_types[t],
                --height = math.random() * 0.12,
                height = 1.0
            }
        end
        return fields
    end
    return build {
        3, 2,
        2, 2,
    }
--     return build{
--         2, 1, 2, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1,
--         1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,

--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,

--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
-- --
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
--     }
end

function shape_terrain_test_sys:init()
    local ww, hh = 2, 2
    local terrain_fields = generate_terrain_fields(ww, hh)
    ecs.create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|shape_terrain",
            "ant.general|name",
        },
        data = {
            name = "shape_terrain_test",
            reference   = true,
            scene = {
                srt = {
                    --t = {-ww//2, 0.0, -hh//2},
                }
            },
            shape_terrain = {
                terrain_fields = terrain_fields,
                width = ww,
                height = hh,
                section_size = math.max(1, ww > 4 and ww//4 or ww//2),
                unit = 1,
                edge = {
                    color = 0xffe5e5e5,
                    thickness = 0.08,
                }
            },
            materials = {
                shape = "/pkg/ant.test.features/assets/shape_terrain.material",
                edge = "/pkg/ant.test.features/assets/shape_terrain_edge.material",
            }
        }
    }
end