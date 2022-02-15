local ecs   = ...
local world = ecs.world
local w     = world.w

local ist       = ecs.import.interface "ant.terrain|ishape_terrain"
local icanvas   = ecs.import.interface "ant.terrain|icanvas"

local shape_terrain_test_sys = ecs.system "shape_terrain_test_system"

--from w: [0, 8], h:[0, 8]
local road_test = {
    -- " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    -- " ", "O2", "I0", "I0", "C2",  " ",  " ",  " ",
    -- " ",  " ",  " ",  " ", "I1",  " ",  " ",  " ",
    -- " ",  " ", "O2", "I0", "X0", "I0", "I0", "O0",
    -- " ",  " ",  " ",  " ", "I1",  " ",  " ",  " ",
    -- " ",  " ", "C3", "I0", "X0", "I0", "O0",  " ",
    -- " ",  " ", "C0", "I0", "C1",  " ",  " ",  " ",
    -- " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ", "O2", "I0", "I0", "O0",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
}

local function build_roads(ww, hh, fields)
    if ww < 8 or hh < 8 then
        error "need at least w>=8 and h>=8 to test road"
    end

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

local function build_indicator_points1(height)
    return {
        {0.0, height, 0.0},
        {1.0, height, 0.0},
        {2.0, height, 0.0},
        -- {2.0, height, 1.0},
        -- {2.0, height, 2.0},
        -- {1.0, height, 2.0},
        -- {0.0, height, 2.0},
        -- {0.0, height, 1.0},
    }
end

local function build_indicator_points(height)
    local points = {}

    local anchors = {}
    local ww, hh = 8, 8
    assert(#road_test == ww*hh)
    for iih=1, 8 do
        for iiw=1, 8 do
            local idx = (iih-1)*ww+iiw
            local r = road_test[idx]
            if r == ' ' then
                goto continue
            end

            local anchor = {iiw-0.5, height, iih-0.5}

            local dx, dz = 0.25, 0.25
            local t, st = r:sub(1, 1), r:sub(2, 2)
            
            if t == "O" then
                --horizontal
                if st == '1' or st == '3' then
                    anchors[idx] ={
                        {anchor[1]-dx, anchor[2], anchor[3]},
                        {anchor[1]+dx, anchor[2], anchor[3]},
                    }
                else
                    anchors[idx] = {
                        {anchor[1], anchor[2], anchor[3]-dz},
                        {anchor[1], anchor[2], anchor[3]+dz},
                    }

                end
            elseif t == "I" then
                if st == "0" then
                    anchors[idx] = {
                        {anchor[1]-dx, anchor[2], anchor[3]},
                        {anchor[1]+dx, anchor[2], anchor[3]},
                    }
                else
                    anchors[idx] = {
                        {anchor[1], anchor[2], anchor[3]-dz},
                        {anchor[1], anchor[2], anchor[3]+dz},
                    }
                end
            elseif t == "C" then
                if st == "0" or st == "3" then
                    anchors[idx] = {
                        {anchor[1]-dx, anchor[2], anchor[3]-dz},
                        {anchor[1]+dx, anchor[2], anchor[3]+dz},
                    }
                else
                    anchors[idx] = {
                        {anchor[1]+dx, anchor[2], anchor[3]-dz},
                        {anchor[1]-dx, anchor[2], anchor[3]+dz},
                    }
                end
            elseif t == "X" then
                anchors[idx] = {
                    {anchor[1]-dx, anchor[2], anchor[3]-dz},
                    {anchor[1]+dx, anchor[2], anchor[3]+dz},
                    {anchor[1]+dx, anchor[2], anchor[3]-dz},
                    {anchor[1]-dx, anchor[2], anchor[3]+dz},
                }
            end

            ::continue::
        end
    end

    --[[
    sub point index:
        O1/O3: 0 for left, 1 for right
        O0/O2: 0 for bottom, 1 for top

        I0: 0 for bottom, 1 for top
        I1: 0 for left, 1 for right

        C0/C3: 0 for leftbottom, 1 for righttop
        C1/C2: 0 for lefttop, 1 for rightbottom

        X: 0 for leftbottom, 1 for righttop, 2 for rightbottom, 3 for lefttop
    ]]

    --[[
        --->x
        |
        |
        z
        (0, 0) for origin point
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ", "O2", "I0", "I0", "O0",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
        " ",  " ",  " ",  " ",  " ",  " ",  " ",  " ",
    ]]

    local directions = {
        10, 0, 11, 0, 12, 0, 13, 0,
        13, 1, 12, 1, 11, 1, 10, 1,
    }

    for i=1, #directions, 2 do
        local aidx, pidx = directions[i], directions[i+1]
        local anchor = anchors[aidx]
        points[#points+1] = anchor[pidx]
    end

    return points
end

local shape_terrain_test

local indicator
local function create_indicator()
    local unit = 1
    local height = 1
    return ecs.create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.asset|material",
            "ant.render|uv_motion",
            "ant.terrain|quad_strip", --in terrain package?
            "ant.general|name",
        },
        data = {
            quad_strip = {
                points = build_indicator_points1(height),
                normal = {0, 1, 0},
                width = 0.5,
                color = {3.0, 3.0, 6.0, 1.0},
                --loop = true,
            },
            uv_motion = {
                speed = {
                    0,--0.025*unit,
                    0,--0.025*unit,
                },
                tile = {
                    3, 1
                },
                rotation = -math.pi*0.5,
            },
            material = "/pkg/ant.test.features/assets/indicator.material",
            scene = {
                srt = {}
            },
            reference = true,
            name = "indicator_test",
        }
    }
end

local canvas = {}

local function create_canvas()
    local unit = 1
    return ecs.create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|canvas",
            "ant.general|name",
        },
        data = {
            name = "canvas",
            scene = {
                srt = {
                    t={0.0, 5.0, 0.0}
                }
            },
            reference = true,
            canvas = {
                textures = {},
                texts = {},
            },
            on_ready = function (e)
                canvas.added_items = 
                icanvas.add_items(e,
                    {
                        texture = {
                            path = "/pkg/ant.test.features/assets/textures/canvas/canvas.texture",
                            size = {w=128, h=128},
                            rect = {
                                x = 0, y = 0,
                                w = 128, h = 128,
                            },
                        },
                        x = 1.2 * unit, y = 2.2 * unit,
                        w = 3 * unit, h = 3 * unit,
                    },
                    {
                        texture = {
                            path = "/pkg/ant.test.features/assets/textures/canvas/canvas.texture",
                            size = {w=128, h=128},
                            rect = {
                                x = 32, y = 32,
                                w = 32, h = 32,
                            },
                        },
                        x = 5 * unit, y = 6 * unit,
                        w = 2 * unit, h = 2 * unit,
                    }
                )
            end
        }
    }
end

function shape_terrain_test_sys:init()
    local ww, hh = 32, 32 --256, 256--2, 2
    local terrain_fields = generate_terrain_fields(ww, hh)
    build_roads(ww, hh, terrain_fields)
    shape_terrain_test = ecs.create_entity{
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
                shape = "/pkg/ant.resources/materials/shape_terrain.material",
                edge = "/pkg/ant.resources/materials/shape_terrain_edge.material",
            }
        }
    }

    --indicator test

    indicator = create_indicator()
    create_canvas()
end

local itr = ecs.import.interface "ant.terrain|iterrain_road"

local kb_mb = world:sub{"keyboard"}

local rotation = 0

function shape_terrain_test_sys:data_changed()
    assert(shape_terrain_test)
    for msg in kb_mb:each() do
        local key, press = msg[2], msg[3]
        if key == "SPACE" and press == 0 then
            if rotation == 4 then
                rotation = 0
            end
            itr.set_road(shape_terrain_test, "C" .. rotation, 1, 2)
            rotation = rotation + 1
        elseif key == "H" and press == 0 then
            if indicator then
                w:remove(indicator)
            end

            indicator = create_indicator()
        elseif key == "D" and press == 0 then
            if canvas.added_items then
                local idx = canvas.added_items[1]
                local ce = w:singleton("canvas", "scene:in")
                icanvas.remove_item(ce, "/pkg/ant.test.features/assets/textures/canvas/canvas.texture", idx)
            end
        end
    end
end