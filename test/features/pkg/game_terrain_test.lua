local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local iterrain      = ecs.require "ant.landform|terrain_system"
local istonemountain= ecs.require "ant.landform|stone_mountain_system"
local itp           = ecs.require "ant.landform|translucent_plane_system"
local iroad         = ecs.require "ant.landform|road"
local iom           = ecs.require "ant.objcontroller|obj_motion"

local S = ecs.system "init_system"

function S.init()
    world:create_instance {
        prefab = "/pkg/vaststars.mod.test/assets/light_directional.prefab",
        on_ready = function (p)
            local pid = p.tag["*"][1]
            local le<close> = world:entity(pid)
            iom.set_direction(le, math3d.vector(0.2664446532726288, -0.25660401582717896, 0.14578714966773987, 0.9175552725791931))
        end,
    }
end

local create_list = {}
local update_list = {}
local delete_list = {}
function S.init_world()


    local mq = w:first("main_queue camera_ref:in")
    local eyepos = math3d.vector(0, 100, -50)
    local camera_ref<close> = world:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)
    iterrain.gen_terrain_field(256, 256, 128)


--[[       world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.render|render",
        },
        data = {
            scene = {t = {-40, 0, 0}},
            mesh  = "/pkg/ant.landform/assets/shapes/road_I.glb|meshes/Plane_P1.meshbin",
            material    = "/pkg/ant.landform/assets/shapes/road_I.glb|materials/Material.001.material",
            visible_state = "main_view|selectable",
            render_layer = "background",
        },
    }  
    
    world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.render|render",
        },
        data = {
            scene = {t = {-20, 0, 0}, r = { axis = {0,1,0}, r = math.rad(180) }},
            mesh  = "/pkg/ant.landform/assets/shapes/road_I.glb|meshes/Plane_P1.meshbin",
            material    = "/pkg/ant.landform/assets/shapes/road_I.glb|materials/Material.001.material",
            visible_state = "main_view|selectable",
            render_layer = "background",
        },
    }  ]]
--[[     local crack_color = math3d.vector(0, 0, 1, 1)
    local crack_emissive = math3d.vector(0, 0, 2, 1)
    world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.render|render",
        },
        data = {
            scene = {t = {10, 0, 10}},
            mesh  = "/pkg/mod.crack/assets/shapes/crack.glb|meshes/Plane_P1.meshbin",
            material    = "/pkg/mod.crack/assets/crack.material",
            visible_state = "main_view|selectable",
            render_layer = "background",
        },
    }
    world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.render|render",
        },
        data = {
            scene = {t = {10, 0, 10}},
            mesh  = "/pkg/mod.crack/assets/shapes/crack.glb|meshes/Plane_P1.meshbin",
            material    = "/pkg/mod.crack/assets/crack_color.material",
            visible_state = "main_view|selectable",
            render_layer = "background",
            on_ready = function(ee)
                imaterial.set_property(ee, "u_crack_color", math3d.vector(crack_color))
                imaterial.set_property(ee, "u_emissive_factor", math3d.vector(crack_emissive))
            end
        },
    }  ]]
    local x, y = 0, -100
    for _, shape in ipairs({"I", "L", "T", "U", "X", "O"}) do
        y = y + 40
        x = - 40
        for rtype = 1, 2 do
            for _, dir in ipairs({"N", "E", "S", "W"}) do
                x = x + 40               
                create_list[#create_list+1] = {
                    x = x, y = y,
                    layers = {
                        road = {type  = rtype, shape = shape, dir = dir},
                        mark = {type  = rtype, shape = shape, dir = dir}
                    }
                }
            end
        end
    end
    iroad.update_roadnet_group(1000, create_list, "translucent")
--[[     create_list = {}
    for _, shape in ipairs({"I", "L", "T", "U", "X", "O"}) do
        y = y + 40
        x = -40
        for rtype = 1, 2 do
            for _, dir in ipairs({"N", "E", "S", "W"}) do
                x = x + 40         
                create_list[#create_list+1] = {
                    x = x, y = y,
                    layers = {
                        mark = {type  = rtype, shape = shape, dir = dir}
                    }
                }
            end
        end
    end
    iroad.update_roadnet_group(1001, create_list, "translucent")  ]]
    
--[[     local density = 0.9
    local width, height, offset, UNIT = 256+10, 256+10, 128+10/2, 10
    local idx_string = istonemountain.create_random_sm(density, width, height, offset, UNIT)
    istonemountain.create_sm_entity(idx_string) ]]

    --istonemountain.create_sm_entity_config(config, width, height, offset, UNIT)    
    --create_mark()
    
--[[      printer_eid = world:create_entity {
        policy = {
            "ant.render|render",
            "mod.printer|printer",
        },
        data = {
            scene  = {s = 0.5, t = {0, 0, 0}},
            material    = "/pkg/mod.printer/assets/printer.material",
            visible_state = "main_view",
            mesh        = "/pkg/vaststars.mod.test/assets/chimney-1.glb|meshes/Plane_P1.meshbin",
            render_layer= "postprocess_obj",
            printer = {
                percent  = printer_percent
            }
        },
    } ]]

--[[       create_instance("/pkg/vaststars.mod.test/assets/miner-1.glb|mesh.prefab",
    function (e)
        local ee<close> = world:entity(e.tag['*'][1])
        iom.set_scale(ee, 1)
        iom.set_position(ee, math3d.vector(200, 0, 0, 1))
    end)  ]]

--[[     create_instance("/pkg/vaststars.mod.test/assets/miner-1.glb|mesh.prefab",
    function (e)
        local ee<close> = world:entity(e.tag['*'][1])
        iom.set_scale(ee, 1)
        iom.set_position(ee, math3d.vector(0, 0, 0, 1))
    end)   ]]
end

local kb_mb = world:sub{"keyboard"}

local tf_table = {}
local remove_id
function S:data_changed()
--[[     for e in w:select "bounding:in" do
        if e.name == "test_road" then
            local center, extent = math3d.aabb_center_extents(e.bounding.scene_aabb)
            local t = 1 
        end
    end ]]
    for _, key, press in kb_mb:unpack() do
        if key == "J" and press == 0 then
            create_list = {
                [1] = {
                    layers = {
                        road = {type  = 1, shape = "U", dir = "N"},
                        mark = {type  = 1, shape = "U", dir = "N"}
                    },
                    
                    x = 0, y = 0 --leftbottom
                },
                [2] = {
                    layers = {
                        road = {type  = 1, shape = "I", dir = "S"},
                        mark = {type  = 1, shape = "I", dir = "S"}
                    },
                    x = 20, y = 0 --leftbottom
                },
                [3] = {
                    layers = {
                        road = {type  = 2, shape = "L", dir = "E"},
                        --mark = {type  = 1, shape = "L", dir = "E"}
                    },
                    x = 40, y = 0 --leftbottom
                },
                [4] = {
                    layers = {
                        road = {type  = 3, shape = "T", dir = "W"},
                        --mark = {type  = 1, shape = "T", dir = "W"}
                    },
                    x = 60, y = 0 --leftbottom
                }
            }
            iroad.update_roadnet_group(0, create_list, "background")
--[[              local x, y = -5, -5
            for _, shape in ipairs({"I", "L", "T", "U", "X", "O"}) do
                y = y + 2
                x = 0
                for rtype = 1, 2 do
                    for _, dir in ipairs({"N", "E", "S", "W"}) do
                        x = x + 2
                        
                        create_list[#create_list+1] = {
                            x = x, y = y,
                            layers = {
                                road = {type  = rtype, shape = shape, dir = dir}
                            }
                        }
                        update_list[#update_list+1] = {
                            x = x, y = y,
                            layers = {
                                mark = {type  = 1, shape = shape, dir = dir}
                            }
                        }
                        delete_list[#delete_list+1] = {
                            x = x, y = y,
                        }
                    end
                end
            end ]]
        
--[[             create_list[#create_list+1] = {
                x = 1, y = 1,
                layers =
                {
                    road =
                    {
                        type  = "3",
                        shape = "I",
                        dir   = "N"                
                    },
                    mark =
                    {
                        type  = "1",
                        shape = "L",
                        dir   = "N"
                    }
                }
            } ]]
        elseif key == "K" and press == 0 then
            create_list = {
                [1] = {
                    layers = {
                        road = {type  = 1, shape = "T", dir = "N"},
                    },
                    x = 0, y = 0 --leftbottom
                },
                [2] = {
                    layers = {
                        road = {type  = 1, shape = "T", dir = "S"},
                    },
                    x = 20, y = 0 --leftbottom
                },
            }
            iroad.update_roadnet_group(0, create_list)
        elseif key == "L" and press == 0 then

            local rect = {x = 5, z = 5, w = 5, h = 5}
            local color = {1, 1, 0, 0.5}
            remove_id = itp.create_translucent_plane(rect, color, "translucent")

--[[              itp.remove_translucent_plane(remove_id)
            remove_id = itp.create_translucent_plane(rect, color, "translucent")   ]]
        elseif key == "N" and press == 0 then
            local rect = {x = 4, z = 4, w = 6, h = 6}
            local color = {1, 0, 0, 0.5}
            remove_id = itp.create_translucent_plane(rect, color, "translucent")  
        elseif key == "M" and press == 0 then
            local rect = {x = 5, z = 5, w = 5, h = 5}
            local color = {1, 1, 0, 0.5}
            itp.remove_translucent_plane(remove_id)
            remove_id = itp.create_translucent_plane(rect, color, "translucent")
        elseif key == "T" and press == 0 then
            local rect = {x = -10, z = 10, w = 20, h = 20}
            itp.create_translucent_plane(rect, {1, 0, 0, 1}, "opacity")  
            local area = istonemountain.get_sm_rect_intersect(rect)
            for k, v in pairs(area) do
                itp.create_translucent_plane(v, {1, 1, 0, 1}, "opacity") 
            end
            local t = 1
        end
    end
end

function S:camera_usage()
 
end
