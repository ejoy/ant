local ecs           = ...
local world         = ecs.world
local w             = world.w
local math3d        = require "math3d"

local ibs           = ecs.require "ant.blur_scene|blur_scene"
local ientity       = ecs.require "ant.render|components.entity"
local imaterial     = ecs.require "ant.asset|material"
local imesh         = ecs.require "ant.asset|mesh"
local iom           = ecs.require "ant.objcontroller|obj_motion"
local irl		    = ecs.require "ant.render|render_layer.render_layer"
local idn           = ecs.require "ant.daynight|daynight"
local itimer        = ecs.require "ant.timer|timer_system"
local ig            = ecs.require "ant.group|group"
local assetmgr      = import_package "ant.asset"
local mathpkg       = import_package"ant.math"
local mc, mu        = mathpkg.constant, mathpkg.util
local renderpkg     = import_package "ant.render"
local layoutmgr     = renderpkg.layoutmgr

local init_loader_sys   = ecs.system 'init_system'
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
        world:create_instance {
            prefab = "/pkg/ant.test.features/assets/entities/light_point.prefab",
            on_ready = function(pl)
                iom.set_position(pl.root, pl)
            end
        }
    end

    world:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/pbr_cube.prefab",
        on_ready = function (ce)
            iom.set_position(ce.root, {0, 0, 0, 1})
        end
    }
    
    world:create_instance {
        prefab = "/pkg/ant.test.features/assets/entities/light_directional.prefab",
    }
end

local function create_texture_plane_entity(color, tex, tex_rect, tex_size)
    local m = imesh.init_mesh(ientity.plane_mesh(mu.texture_uv(tex_rect, tex_size)))
    m.vb.owned = true
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
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

local cp_eid, quad_eid
local testprefab

local function create_instance(prefab, on_ready)
    local p = world:create_instance {
        prefab = prefab,
        on_ready = on_ready,
    }
end

local after_init_mb = world:sub{"after_init"}
function init_loader_sys:init()
    
    ientity.create_grid_entity(128, 128, 1, 3)
    create_instance("/pkg/ant.test.features/assets/entities/light.prefab",
    
    function (e)

    end)

     create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
        local root<close> = world:entity(e.tag['*'][1])
        iom.set_position(root, math3d.vector(3, 1, 0))
    end) 

end

local velocity_eid
local function render_layer_test()
    irl.add_layers(irl.layeridx "background", "mineral", "translucent_plane", "translucent_plane1")
    local m = imesh.init_mesh(ientity.plane_mesh())
--[[     velocity_eid = world:create_entity {
        policy = {
            "ant.render|render",
         },
        data = {
            scene  = {s = 1, t = {0, 1, 0}},
            --material    = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/Material.001_nup.material",
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
     --world:create_instance  "/pkg/ant.test.features/assets/entities/outline_duck.prefab"
    --world:create_instance  "/pkg/ant.test.features/assets/entities/outline_wind.prefab" 
--[[     create_instance("/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab", function (e)
        local ee <close> = world:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, -2, 0))
        iom.set_scale(ee, 3)
        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = world:entity(eid, "render_layer?update render_object?update")
            if ee.render_layer and ee.render_object then
                irl.set_layer(ee, "mineral")
            end
        end
    end)

    world:create_entity {
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh = m,
            scene = {t = {-10, 0, 0}, s = 10},
            material = "/pkg/ant.test.features/assets/render_layer_test.material",
            render_layer = "translucent_plane",
            visible_state = "main_view",
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
        local ee <close> = world:entity(e.tag['*'][1])
        iom.set_position(ee, math3d.vector(-10, 0, -1))

        for _, eid in ipairs(e.tag['*']) do
            local ee <close> = world:entity(eid, "render_layer?update render_object?update")
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
--[[     sm_id = world:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/mountain1.glb|meshes/Cylinder.002_P1.meshbin",
            scene = {s = {0.125, 0.125, 0.125}, t = {5, 0, 5}},
            material = "/pkg/ant.test.features/mountain1.glb|materials/Material_cnup.material",
            --material = "/pkg/ant.test.features/assets/pbr_test.material",
            visible_state = "main_view",
        }
    } ]]
--[[     world:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/t1.glb|meshes/zhuti.025_P1.meshbin",
            scene = {},
            material = "/pkg/ant.test.features/assets/t1.glb|materials/Material.material",
            visible_state = "main_view",
        }
    }
    world:create_entity {
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.test.features/assets/cube.glb|meshes/Cube_P1.meshbin",
            scene = {t = {-5, 5, 0}},
            material = "/pkg/ant.test.features/assets/cube.glb|materials/Material.001.material",
            visible_state = "main_view",
        }
    } ]]

end

local canvas_eid
local function canvas_test()
    canvas_eid = world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|canvas",
        },
        data = {
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
    local camera_ref<close> = world:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)

    render_layer_test()
    canvas_test()

    drawindirect_test()
end


local kb_mb = world:sub{"keyboard"}

local mouse_mb = world:sub{"mouse", "LEFT"}

local enable = 1
local sm_test = false
local itemsids
local bse, output_handle
function init_loader_sys:ui_update()

    for _, key, press in kb_mb:unpack() do
        if key == "A" and press == 0 then
            bse, output_handle = ibs.blur_scene()
        elseif key == "B" and press == 0 then
            w:remove(bse)
        elseif key == "T" and press == 0 then
            -- local e<close> = world:entity(quad_eid)
            -- ivs.set_visible(e, "main_view", true)

            -- local quad_2 = 2
            -- e.render_object.ib_num = quad_2 * 6
        elseif key == "Y" and press == 0 then
            local mesh_eid = testprefab.tag["*"][2]
            local te<close> = world:entity(mesh_eid)
            local t = assetmgr.resource "/pkg/ant.test.features/assets/glb/headquater-1.glb|images/headquater_color.texture"
            imaterial.set_property(te, "s_basecolor", t.id)
        elseif key == "N" and press == 0 then
            -- local icw = ecs.require "ant.render|curve_world"
            -- icw.enable(not icw.param().enable)

            --imaterial.set_color_palette("default", 0, math3d.vector(1.0, 0.0, 1.0, 0.0))
            
            local go <close> = ig.obj "view_visible"
            go:enable(1, enable == 1)
            go:enable(0, enable == 1)
            enable = enable == 1 and 0 or 1

        elseif key == "LEFT" and press == 0 then
            local d = w:first("directional_light scene:in eid:in")
            iom.set_position(d, {0, 1, 0})
        elseif key == "C" and press == 0 then
            local icanvas = ecs.require "ant.terrain|canvas"
            if itemsids then
                icanvas.show(world:entity(canvas_eid), false)
                icanvas.remove_item(world:entity(canvas_eid), itemsids[1])
                itemsids = nil
                return
            end
            itemsids = icanvas.add_items(world:entity(canvas_eid), "/pkg/ant.test.features/assets/canvas_texture.material", "background",
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
            local sm = world:entity(sm_id, "bounding:in")
            local center, extent = math3d.aabb_center_extents(sm.bounding.aabb)
            local t1, t2 = math3d.tovalue(center), math3d.tovalue(extent)
            local t3 =  1
        elseif key == "O" and press == 0 then
            local e = assert(world:entity(sampler_eid))
            print(math3d.tostring(iom.get_position(e)))
        elseif key == "J" and press == 0 then

        elseif key == "K" and press == 0 then
        elseif key == "L" and press == 0 then
            local ee <close> = world:entity(outline_eid, "outline_remove?update")
            ee.outline_remove = true
        elseif key == "M" and press == 0 then
            local irender = ecs.require "ant.render|render_system.render"
            local whichratio = "scene_ratio"    -- "ratio"
            local r = irender.get_framebuffer_ratio(whichratio)
            irender.set_framebuffer_ratio(whichratio, r - 0.1)
        end
    end


end

function init_loader_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne then
        local tenSecondMS<const> = 10000
        local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
        idn.update_cycle(dne, cycle)
    end
end

function init_loader_sys:camera_usage()
    -- for _, _, state, x, y in mouse_mb:unpack() do
    --     local mq = w:first("main_queue render_target:in camera_ref:in")
    --     local ce = world:entity(mq.camera_ref, "camera:in")
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