local ecs   = ...
local world = ecs.world
local w     = world.w

local ist = ecs.import.interface "ant.terrain|ishape_terrain"
local shape_terrain_test_sys = ecs.system "shape_terrain_test_system"


local function build_roads(ww, hh, fields)
    if ww < 8 or hh < 8 then
        error "need at least w>=8 and h>=8 to test road"
    end

    --from w: [0, 8], h:[0, 8]
    local road_test = {
         " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
         " ", "O2", "I0", "I0", "C2",  " ",  " ",  " ",
         " ",  " ",  " ",  " ", "I1",  " ",  " ",  " ",
         " ",  " ", "O2", "I0", "X0", "I0", "I0", "O0",
         " ",  " ",  " ",  " ", "I1",  " ",  " ",  " ",
         " ",  " ", "C3", "I0", "X0", "I0", "O0",  " ",
         " ",  " ", "C0", "I0", "C1",  " ",  " ",  " ",
         " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    }

    for iih=1, 8 do
        for iiw=1, 8 do
            local idx = (iih-1)*ww+iiw
            local idx1 = (iih-1)*8+iiw
            local rt = road_test[idx1]

            fields[idx].type ="grass"
            if rt ~= " " then
                fields[idx].roadtype = rt
            end
        end
    end
end

local function generate_terrain_fields(w, h)
    local shapetypes = ist.shape_types()

    local fields = {}
    for ih=1, h do
        for iw=1, w do
            local which = math.random(1, 3)
            local height = math.random() * 0.05
            fields[#fields+1] = {
                type    = shapetypes[which],
                height  = height,
            }
        end
    end

    return fields
    -- local function build(stream)
    --     local fields = {}
    --     for _, t in ipairs(stream) do
    --         fields[#fields+1] = {
    --             type = shape_types[t],
    --             --height = math.random() * 0.12,
    --             height = 1.0
    --         }
    --     end
    --     return fields
    -- end
    -- return build {
    --     3, 2,
    --     2, 2,
    -- }
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
    local ww, hh = 16, 16--256, 256--2, 2
    local terrain_fields = generate_terrain_fields(ww, hh)
    build_roads(ww, hh, terrain_fields)
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
                    t = {-ww//2, 0.0, -hh//2},
                }
            },
            shape_terrain = {
                terrain_fields = terrain_fields,
                width = ww,
                height = hh,
                section_size = math.max(1, ww > 4 and ww//4 or ww//2),
                unit = 2,
                edge = {
                    color = 0xffe5e5e5,
                    thickness = 0.08,
                },
            },
            materials = {
                shape = "/pkg/ant.test.features/assets/shape_terrain.material",
                edge = "/pkg/ant.test.features/assets/shape_terrain_edge.material",
            }
        }
    }
end