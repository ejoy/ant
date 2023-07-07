local ecs           = ...
local world         = ecs.world
local w             = world.w
local math3d        = require "math3d"

local ientity       = ecs.import.interface "ant.render|ientity"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
local imesh         = ecs.import.interface "ant.asset|imesh"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local irl           = ecs.import.interface "ant.render|irender_layer"
local idn           = ecs.import.interface "ant.daynight|idaynight"
local itimer        = ecs.import.interface "ant.timer|itimer"

local ims           = ecs.import.interface "ant.motion_sampler|imotion_sampler"

local assetmgr      = import_package "ant.asset"

local mathpkg       = import_package"ant.math"
local mc, mu        = mathpkg.constant, mathpkg.util

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr

local init_loader_sys   = ecs.system 'init_loader_system'
local iheapmesh = ecs.import.interface "ant.render|iheapmesh"
local printer_eid
local printer_percent = 0
local function point_light_test()
    local pl_pos = {
        {  1, 0, 1},
        { -1, 0, 1},
        { -1, 0,-1},
        {  1, 0,-1},
        {  1, 2, 1},
        { -1, 2, 1},
        { -1, 2,-1},
        {  1, 2,-1},

        {  3, 0, 3},
        { -3, 0, 3},
        { -3, 0,-3},
        {  3, 0,-3},
        {  3, 2, 3},
        { -3, 2, 3},
        { -3, 2,-3},
        {  3, 2,-3},
    }

    for _, p in ipairs(pl_pos) do
        local  pl = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
        pl.on_ready = function()
            iom.set_position(pl.root, p)
        end
        world:create_object(pl)
    end

    local ce = ecs.create_instance  "/pkg/ant.test.features/assets/entities/pbr_cube.prefab"[1]
    ce.on_ready = function ()
        iom.set_position(ce.root, {0, 0, 0, 1})
    end
    world:create_object(ce)
    

    ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"
end

local function create_texture_plane_entity(color, tex, tex_rect, tex_size)
    local m = imesh.init_mesh(ientity.plane_mesh(mu.texture_uv(tex_rect, tex_size)))
    m.vb.owned = true
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name = "test_texture_plane",
            simplemesh = m,
            owned_mesh_buffer = true,
            material = "/pkg/ant.resources/materials/texture_plane.material",
            visible_state= "main_view",
            render_layer = "background",
            scene   = { srt = {t={0, 5, 5}}},
            on_ready = function (e)
                imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color))
                local texobj = assetmgr.resource(tex)
                imaterial.set_property(e, "s_basecolor", texobj.handle)
            end
        }
    }
end

local function color_palette_test()
    local bgfx = require "bgfx"
    return ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = {
                vb = {
                    start = 0, num = 3,
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {
                        0.0, 0.0, 0.0, 
                        0.0, 0.0, 1.0,
                        1.0, 0.0, 0.0,
                    }), declmgr.get "p3".handle)
                }
            },
            material = "/pkg/ant.resources/materials/color_palette_test.material",
            visible_state = "main_view",
            scene = {srt={}},
            name = "color_pal_test",
        }
    }
end

local cp_eid, quad_eid
local testprefab

local function create_instance(prefab, onready)
    local p = ecs.create_instance(prefab)
    p.on_ready = onready
    world:create_object(p)
end

local after_init_mb = world:sub{"after_init"}
function init_loader_sys:init()
    
    ientity.create_grid_entity("grid", 128, 128, 1, 3)
    create_instance("/pkg/ant.test.features/assets/entities/light.prefab",
    
    function (e)

    end)

     create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
        local root<close> = w:entity(e.tag['*'][1])
        iom.set_position(root, math3d.vector(3, 1, 0))
    end) 
    --ecs.create_instance "/pkg/ant.test.features/assets/entities/daynight.prefab"

end

local velocity_eid
local function render_layer_test()
    irl.add_layers(irl.layeridx "background", "mineral", "translucent_plane", "translucent_plane1")
    local m = imesh.init_mesh(ientity.plane_mesh())
--[[     velocity_eid = ecs.create_entity {
        policy = {
            "ant.render|render",
         },
        data = {
            scene  = {s = 1, t = {0, 1, 0}},
            --material    = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/Material.001.material",
            --material    = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|materials/Material.001_skin.material",
            --material    = "/pkg/ant.resources/materials/pbr_stencil.material", 
            --material    = "/pkg/ant.resources.binary/meshes/Duck.glb|materials/blinn3-fx.material", 
            material    = "/pkg/ant.resources.binary/meshes/Damagedhelmet.glb|materials/Material_MR.material", 
            --material    = "/pkg/ant.resources.binary/meshes/chimney-1.glb|materials/Material_skin_clr.material",
            --material    = "/pkg/ant.resources.binary/meshes/furnace-1.glb|materials/Material_skin.material",
            visible_state = "main_view|velocity_queue",
            --mesh        = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|meshes/Plane.003_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/Duck.glb|meshes/LOD3spShape_P1.meshbin",
            mesh        = "/pkg/ant.resources.binary/meshes/Damagedhelmet.glb|meshes/mesh_helmet_LP_13930damagedHelmet_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/chimney-1.glb|meshes/Plane_P1.meshbin",
            --mesh        = "/pkg/ant.resources.binary/meshes/furnace-1.glb|meshes/Cylinder.001_P1.meshbin",

        },
    } ]]
     --ecs.create_instance  "/pkg/ant.test.features/assets/entities/outline_duck.prefab"
    --ecs.create_instance  "/pkg/ant.test.features/assets/entities/outline_wind.prefab" 
--[[     create_instance("/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab", function (e)
        local ee <close> = w:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, -2, 0))
        iom.set_scale(ee, 3)
        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = w:entity(eid, "render_layer?update render_object?update")
            if ee.render_layer and ee.render_object then
                irl.set_layer(ee, "mineral")
            end
        end
    end)

    ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = m,
            scene = {t = {-10, 0, 0}, s = 10},
            material = "/pkg/ant.test.features/assets/render_layer_test.material",
            render_layer = "translucent_plane",
            visible_state = "main_view",
            name = "test",
            on_ready = function (e)
                imaterial.set_state(e, {
                    ALPHA_REF = 0,
                    CULL = "CCW",
                    DEPTH_TEST = "GREATER",
                    MSAA = true,
                    WRITE_MASK = "RGBAZ"
                })
            end
        }
    }

    create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
        local ee <close> = w:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, 0, -1))

        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = w:entity(eid, "render_layer?update render_object?update")
            if ee.render_layer and ee.render_object then
                irl.set_layer(ee, "translucent_plane1")
            end
        end
    end) ]]
end


local sampler_eid
local heap_eid
local sm_id
local function drawindirect_test()
    sm_id = ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.test.features/mountain1.glb|meshes/Cylinder.002_P1.meshbin",
            scene = {s = {0.125, 0.125, 0.125}, t = {5, 0, 5}},
            material = "/pkg/ant.test.features/mountain1.glb|materials/Material_clr.material",
            --material = "/pkg/ant.test.features/assets/pbr_test.material",
            visible_state = "main_view",
            name = "test",
        }
    }
--[[     ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/t1.glb|meshes/zhuti.025_P1.meshbin",
            scene = {},
            material = "/pkg/ant.test.features/assets/t1.glb|materials/Material.material",
            visible_state = "main_view",
            name = "test",
        }
    }
    ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/cube.glb|meshes/Cube_P1.meshbin",
            scene = {t = {-5, 5, 0}},
            material = "/pkg/ant.test.features/assets/cube.glb|materials/Material.001.material",
            visible_state = "main_view",
            name = "test",
        }
    } ]]
--[[     heap_eid = ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.render|heap_mesh",
            "ant.render|indirect"
         },
        data = {
            scene  = {s = 0.2, t = {0, 0, 0}},
            material    = "/pkg/ant.resources/materials/pbr_heap.material", -- 自定义material文件中需加入HEAP_MESH :1
            visible_state = "main_view",
            mesh        = "/pkg/ant.resources.binary/meshes/iron-ore.glb|meshes/Cube.001_P1.meshbin",
            heapmesh = {
                curSideSize = {4, 4, 4}, -- 当前 x y z方向最大堆叠数量为3, 4, 5，通过表的形式赋值给curSideSize，最大堆叠数为3*4*5 = 60
                curHeapNum = 20, -- 当前堆叠数为10，以x->z->y轴的正方向顺序堆叠。最小为0，最大为10，超过边界值时会clamp到边界值。
                glbName = "iron-ingot", -- 当前entity对应的glb名字，用于筛选
                interval = {0.5, 0.5, 0.5}
            },
            indirect = "HEAP_MESH",
            render_layer = "background"
        },
    }   ]]
    
--[[     ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.render|heap_mesh",
         },
        data = {
            scene  = {s = 0.2, t = {20, 0, 0}},
            material    = "/pkg/ant.resources/materials/pbr_heap.material", -- 自定义material文件中需加入HEAP_MESH :1
            visible_state = "main_view",
            mesh        = "/pkg/ant.resources.binary/meshes/iron-ore.glb|meshes/Cube.001_P1.meshbin",
            heapmesh = {
                curSideSize = {3, 3, 3}, -- 当前 x y z方向最大堆叠数量为3, 4, 5，通过表的形式赋值给curSideSize，最大堆叠数为3*4*5 = 60
                curHeapNum = 15, -- 当前堆叠数为10，以x->z->y轴的正方向顺序堆叠。最小为0，最大为10，超过边界值时会clamp到边界值。
                glbName = "iron-ingot", -- 当前entity对应的glb名字，用于筛选
                interval = {0.5, 0.5, 0.5}
            },
            indirect = "HEAP_MESH"
        },
    }   ]]

   local t = 1  
--[[      ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "ant.render|heap_mesh",
         },
        data = {
            name        = "heap_mesh_test",
            scene  = {s = 0.2, t = {0, 3, 0}},
            material    = "/pkg/ant.resources/materials/heap_test.material",
            visible_state = "main_view",
            mesh        = "/pkg/ant.test.features/assets/glb/iron-ingot.glb|meshes/Cube.252_P2.meshbin",
            heapmesh = {
                curSideSize = 3,
                curHeapNum = 10,
                glbName = "iron-ingot"
            }
        },
    }    ]] 
end

local function motion_sampler_test()
    local g = ims.sampler_group()
    local eid = g:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.motion_sampler|motion_sampler",
            "ant.general|name",
        },
        data = {
            scene = {},
            name = "motion_sampler",
            motion_sampler = {
                keyframes = {
                    {r = math3d.quaternion{0.0, 0.0, 0.0}, t = math3d.vector(0.0, 0.0, 0.0), step = 0.0},
                    {                                      t = math3d.vector(1.0, 0.0, 2.0), step = 0.5},
                    {r = math3d.quaternion{0.0, 1.2, 0.0}, t = math3d.vector(0.0, 0.0, 2.0), step = 1.0}
                }
            }
        }
    }
    sampler_eid = eid

    g:enable "view_visible"

--[[     local p = g:create_instance("/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab", eid)
    p.on_ready = function (e)
        
    end

    world:create_object(p) ]]
end

local canvas_eid
local function canvas_test()
    canvas_eid = ecs.create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|canvas",
            "ant.general|name",
        },
        data = {
            name = "canvas",
            scene = {
                t = {0.0, 2, 0.0},
            },
            canvas = {
                show = true,
            },
        }
    }
end

local heap_num = 1



function init_loader_sys:init_world()

    for msg in after_init_mb:each() do
        local e = msg[2]
        local s = iom.get_scale(e)
        iom.set_scale(e, math3d.mul(s, {5, 5, 5, 0}))
    end

    local mq = w:first("main_queue camera_ref:in")
    local eyepos = math3d.vector(0, 8, -8)
    local camera_ref<close> = w:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)

    render_layer_test()
    canvas_test()

    motion_sampler_test()
    drawindirect_test()
end

local kb_mb = world:sub{"keyboard"}

local mouse_mb = world:sub{"mouse", "LEFT"}

local enable = 1
local sm_test = false
local itemsids
function init_loader_sys:ui_update()
    for _, key, press in kb_mb:unpack() do
        if key == "T" and press == 0 then
            -- local e<close> = w:entity(quad_eid)
            -- ivs.set_visible(e, "main_view", true)

            -- local quad_2 = 2
            -- e.render_object.ib_num = quad_2 * 6
        elseif key == "Y" and press == 0 then
            local mesh_eid = testprefab.tag["*"][2]
            local te<close> = w:entity(mesh_eid)
            local t = assetmgr.resource "/pkg/ant.test.features/assets/glb/headquater-1.glb|images/headquater_color.texture"
            imaterial.set_property(te, "s_basecolor", t.id)
        elseif key == "N" and press == 0 then
            -- local icw = ecs.import.interface "ant.render|icurve_world"
            -- icw.enable(not icw.param().enable)

            --imaterial.set_color_palette("default", 0, math3d.vector(1.0, 0.0, 1.0, 0.0))
            
            if enable == 1 then
                ecs.group(1):enable "view_visible"
                ecs.group(0):disable "view_visible"
            else
                ecs.group(0):enable "view_visible"
                ecs.group(1):disable "view_visible"
            end
            enable = enable == 1 and 0 or 1

        elseif key == "LEFT" and press == 0 then
            local d = w:first("directional_light scene:in eid:in")
            iom.set_position(d, {0, 1, 0})
        elseif key == "C" and press == 0 then
            local icanvas = ecs.import.interface "ant.terrain|icanvas"
            if itemsids then
                icanvas.show(w:entity(canvas_eid), false)
                icanvas.remove_item(w:entity(canvas_eid), itemsids[1])
                itemsids = nil
                return
            end
            itemsids = icanvas.add_items(w:entity(canvas_eid), "/pkg/ant.test.features/assets/canvas_texture.material", "background",
            {
                x = 2, y = 2, w = 4, h = 4,
                texture = {
                    rect = {
                        x = 0, y = 0,
                        w = 32, h = 32,
                    },
                },
            },
            {
                x = 0, y = 0, w = 2, h = 2,
                texture = {
                    rect = {
                        x = 32, y = 32,
                        w = 32, h = 32,
                    },
                },
            }
        )
        elseif key == "P" and press == 0 then
--[[             local e = assert(w:entity(sampler_eid))
            ims.set_keyframes(e, 
                {t = math3d.vector(0.0, 0.0, 0.0), 0.0},
                {t = math3d.vector(0.0, 0.0, 2.0), 1.0}
            ) ]]
            local sm = w:entity(sm_id, "bounding:in")
            local center, extent = math3d.aabb_center_extents(sm.bounding.aabb)
            local t1, t2 = math3d.tovalue(center), math3d.tovalue(extent)
            local t3 =  1
        elseif key == "O" and press == 0 then
            local e = assert(w:entity(sampler_eid))
            print(math3d.tostring(iom.get_position(e)))
        elseif key == "J" and press == 0 then
            iheapmesh.update_heap_mesh_number(heap_eid, heap_num) -- 更新当前堆叠数 参数一为待更新堆叠数 参数二为entity筛选的eid
            heap_num = heap_num + 1
        elseif key == "K" and press == 0 then
            --iheapmesh.update_heap_mesh_number(0, "iron-ingot")   -- 更新当前堆叠数
            render_layer_test()
        elseif key == "L" and press == 0 then
            local ee <close> = w:entity(outline_eid, "outline_remove?update")
            ee.outline_remove = true
        elseif key == "M" and press == 0 then

        end
    end


end

function init_loader_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne then
        local tenSecondMS<const> = 10000
        local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
        idn.update_day_cycle(dne, cycle)
    end

    local mse = w:first "motion_sampler:update"
    if mse then
        local tenSecondMS<const> = 10000
        ims.set_ratio(mse, (itimer.current() % tenSecondMS) / tenSecondMS)
    end
end

function init_loader_sys:camera_usage()
    -- for _, _, state, x, y in mouse_mb:unpack() do
    --     local mq = w:first("main_queue render_target:in camera_ref:in")
    --     local ce = w:entity(mq.camera_ref, "camera:in")
    --     local camera = ce.camera
    --     local vpmat = camera.viewprojmat
    
    --     local vr = mq.render_target.view_rect
    --     local nx, ny = mu.remap_xy(x, y, vr.ratio)
    --     local ndcpt = mu.pt2D_to_NDC({nx, ny}, vr)
    --     ndcpt[3] = 0
    --     local p0 = mu.ndc_to_world(vpmat, ndcpt)
    --     ndcpt[3] = 1
    --     local p1 = mu.ndc_to_world(vpmat, ndcpt)
    
    --     local ray = {o = p0, d = math3d.sub(p0, p1)}
    
    --     local plane = math3d.vector(0, 1, 0, 0)
    --     local r = math3d.muladd(ray.d, math3d.plane_ray(ray.o, ray.d, plane), ray.o)
        
    --     print("click:", x, y, math3d.tostring(r), "view_rect:", vr.x, vr.y, vr.w, vr.h)
    -- end
end

--[[ instance_info = {
    mesh = ,
    material = ,
    render_layer = ,
    visible_state = ,
    diff_table = {
        srt_table = {}
    }
} ]]