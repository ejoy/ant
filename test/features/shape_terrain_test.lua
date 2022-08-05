local ecs   = ...
local world = ecs.world
local w     = world.w

local icanvas   = ecs.import.interface "ant.terrain|icanvas"

local shape_terrain_test_sys = ecs.system "shape_terrain_test_system"

local function build_indicator_points1(height)
    return {
        {0.0, height, 0.0},
        {1.0, height, 0.0},
        {2.0, height, 0.0},
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
                t={0.0, 5.0, 0.0}
            },
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
                            rect = {
                                x = 0, y = 0,
                                w = 128, h = 128,
                            },
                            srt = {
                                r = math.pi * 0.25, -- rotate 45 degree
                            }
                        },
                        x = 1.2 * unit, y = 2.2 * unit,
                        w = 3 * unit, h = 3 * unit,
                        srt = {
                            r = math.rad(30),
                            s = {1.2, 1.5},
                            t = {0.2, 0.5}
                        }
                    },
                    {
                        texture = {
                            path = "/pkg/ant.test.features/assets/textures/canvas/canvas.texture",
                            rect = {
                                x = 32, y = 32,
                                w = 32, h = 32,
                            },
                            srt = {
                                r = math.pi * 0.15,
                                t = {0.1, 0.2},
                                s = {1.2, 1.2},
                            }
                        },
                        x = 5 * unit, y = 6 * unit,
                        w = 2 * unit, h = 2 * unit,
                    }
                )
            end
        }
    }
end

local function generate_mesh_shape(ww, hh)
    local mw, mh = 2, 2
    local ms = {
        meshes = {
            "/pkg/ant.test.features/assets/entities/testmesh.prefab",
            "/pkg/ant.test.features/assets/entities/testmesh.prefab",
            "/pkg/ant.test.features/assets/entities/testmesh.prefab",
            "/pkg/ant.test.features/assets/entities/testmesh.prefab",
        },
        w = mw, h = mh,
    }

    local www, hhh = ww // mw, hh // mh
    for ih=1, hhh do
        local ridx = (ih-1) * www
        for iw=1, www do
            ms[iw+ridx] = math.random(1, 4)
        end
    end

    return ms
end

function shape_terrain_test_sys:init()
    local ww, hh = 8, 8 --256, 256--2, 2
    shape_terrain_test = ecs.create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|shape_terrain",
            "ant.general|name",
        },
        data = {
            name = "shape_terrain_test",
            scene = {
                srt = {
                    t = {-ww//2, 0.0, -hh//2},
                }
            },
            shape_terrain = {
                width = ww,
                height = hh,
                unit = 2.0,
                -- cube_shape = {
                --     fields = generate_terrain_fields(ww, hh),
                --     section_size = math.max(1, ww > 4 and ww//4 or ww//2),
                --     unit = 2,
                --     edge = {
                --         color = 0xffe5e5e5,
                --         thickness = 0.08,
                --     },
                -- }
                mesh_shape = generate_mesh_shape(ww, hh)
            },
        }
    }

    --indicator test

    indicator = create_indicator()
    create_canvas()
end

local kb_mb = world:sub{"keyboard"}

function shape_terrain_test_sys:data_changed()
    assert(shape_terrain_test)
    for msg in kb_mb:each() do
        local key, press = msg[2], msg[3]
        if key == "H" and press == 0 then
            if indicator then
                w:remove(indicator)
            end

            indicator = create_indicator()
        elseif key == "T" and press == 0 then
            local ce = w:singleton("canvas", "scene:in")
            local unit = 1.0
            local itemid = icanvas.add_items(ce, {
                {
                    texture = {
                        path = "/pkg/ant.resources/textures/white.texture",
                        size = {
                            w = 1, h = 1,
                        },
                        rect = {
                            x = 0, y = 0,
                            w = 1, h = 1,
                        },
                    },
                    x = 0 * unit, y = 0 * unit,
                    w = 2 * unit, h = 2 * unit,
                }
            })

            icanvas.show(itemid, true)
        elseif key == "M" and press == 0 then
            if canvas.added_items then
                local ce = w:singleton("canvas", "scene:in")
                icanvas.remove_item(ce, canvas.added_items[1])
            end
        elseif key == "N" and press == 0 then
            if canvas.added_items then
                local ce = w:singleton("canvas", "scene:in")
                local unit = 1.0
                icanvas.update_item_rect(ce, canvas.added_items[#canvas.added_items], {
                    x=2*unit, y=3*unit,
                    w=2*unit, h=2*unit
                })
            end
        end
    end
end