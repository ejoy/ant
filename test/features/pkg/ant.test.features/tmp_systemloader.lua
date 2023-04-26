local ecs           = ...
local world         = ecs.world
local w             = world.w
local math3d        = require "math3d"

local ientity       = ecs.import.interface "ant.render|ientity"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
local imesh         = ecs.import.interface "ant.asset|imesh"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local irl           = ecs.import.interface "ant.render|irender_layer"
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
        local pid = e.tag["*"][2]

        local le<close> = w:entity(pid)
        iom.set_direction(le, math3d.vector(0.2664446532726288, -0.25660401582717896, 0.14578714966773987, 0.9175552725791931))
    end)
    ecs.create_instance "/pkg/ant.test.features/assets/entities/daynight.prefab"

end

local function render_layer_test()
    irl.add_layers(irl.layeridx "opacity", "after_opacity", "after_opacity2")
    local m = imesh.init_mesh(ientity.plane_mesh())

    ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = m,
            scene = {},
            material = "/pkg/ant.test.features/assets/render_layer_test.material",
            render_layer = "after_opacity2",
            visible_state = "main_view",
            name = "test",
        }
    }

    ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = m,
            scene = {
                t = {0.5, 0.0, 0.0}
            },
            material = "/pkg/ant.test.features/assets/render_layer_test.material",
            render_layer = "after_opacity",
            visible_state = "main_view",
            on_ready = function (e)
                imaterial.set_property(e, "u_basecolor_factor", math3d.vector(1.0, 0.0, 0.0, 1.0))
            end,
            name = "test",
        }
    }
end

local sampler_eid

local function drawindirect_test()
--[[         ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "ant.render|heap_mesh",
         },
        data = {
            name        = "heap_mesh_test",
            scene  = {s = 0.2, t = {2, 0, 0}},
            material    = "/pkg/ant.resources/materials/pbr_heap.material", -- 自定义material文件中需加入HEAP_MESH :1
            visible_state = "main_view",
            mesh        = "/pkg/ant.test.features/assets/glb/iron-ore.glb|meshes/Cube_P1.meshbin",
            heapmesh = {
                curSideSize = {4, 4, 4}, -- 当前 x y z方向最大堆叠数量为3, 4, 5，通过表的形式赋值给curSideSize，最大堆叠数为3*4*5 = 60
                curHeapNum = 64, -- 当前堆叠数为10，以x->z->y轴的正方向顺序堆叠。最小为0，最大为10，超过边界值时会clamp到边界值。
                glbName = "iron-ingot", -- 当前entity对应的glb名字，用于筛选
                interval = {0.5, 0.5, 0.5}
            }
        },
    }  ]]
   
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
    local ims = ecs.import.interface "ant.motion_sampler|imotion_sampler"
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
            on_ready = function (e)
                ims.set_target(e, nil, math3d.quaternion{0.0, 1.2, 0.0}, math3d.vector(0.0, 0.0, 2.0), 2000)
            end
        }
    }
    sampler_eid = eid

    g:enable "view_visible"
    g:enable "scene_update"

    local p = g:create_instance("/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab", eid)
    p.on_ready = function (e)
        
    end

    world:create_object(p)
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
                t = {0.0, 10, 0.0},
            },
            canvas = {
                textures = {},
                texts = {},
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
function init_loader_sys:entity_init()
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
                ecs.group(1):enable "scene_update"

                ecs.group(0):disable "view_visible"
                ecs.group(0):disable "scene_update"
            else
                ecs.group(0):enable "view_visible"
                ecs.group(0):enable "scene_update"

                ecs.group(1):disable "view_visible"
                ecs.group(1):disable "scene_update"
            end
            enable = enable == 1 and 0 or 1

        elseif key == "LEFT" and press == 0 then
            local d = w:first("directional_light scene:in eid:in")
            iom.set_position(d, {0, 1, 0})
        elseif key == "C" and press == 0 then
            local icanvas = ecs.import.interface "ant.terrain|icanvas"
            icanvas.add_items(w:entity(canvas_eid), "/pkg/ant.test.features/assets/canvas_texture.material", "background",
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
            local e = assert(w:entity(sampler_eid))
            local p = math3d.add(iom.get_position(e), math3d.vector(0.0, 0.0, 1.0))
            local ims = ecs.import.interface "ant.motion_sampler|imotion_sampler"
            ims.set_target(e, nil, nil, p, 100)

        elseif key == "O" and press == 0 then
            local e = assert(w:entity(sampler_eid))
            print(math3d.tostring(iom.get_position(e)))
        elseif key == "J" and press == 0 then
            iheapmesh.update_heap_mesh_number(heap_num, "iron-ingot") -- 更新当前堆叠数 参数一为待更新堆叠数 参数二为entity筛选的glb名字
            heap_num = heap_num + 1
        elseif key == "K" and press == 0 then
            iheapmesh.update_heap_mesh_number(0, "iron-ingot")   -- 更新当前堆叠数
        end
    end


end

function init_loader_sys:data_changed()
    local idn = ecs.import.interface "ant.daynight|idaynight"
    local itimer = ecs.import.interface "ant.timer|itimer"
    local dne = w:first "daynight:in"
    local tenSecondMS<const> = 10000
    local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
    idn.update_day_cycle(dne, cycle)
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

