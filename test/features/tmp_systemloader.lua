local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local ientity = ecs.import.interface "ant.render|ientity"
local ivs = ecs.import.interface "ant.scene|ivisible_state"
local init_loader_sys = ecs.system 'init_loader_system'
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh = ecs.import.interface "ant.asset|imesh"
local assetmgr = import_package "ant.asset"

local bgfx = require "bgfx"

local mathpkg = import_package"ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local camerapkg = import_package"ant.camera"
local split_frustum = camerapkg.split_frustum

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local icamera = ecs.import.interface "ant.camera|icamera"
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

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

local after_init_mb = world:sub{"after_init"}
function init_loader_sys:init()
    --point_light_test()
    -- local eid1, eid2, eid3 = ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
    -- print(eid1, eid2, eid3)

    -- local pp = ecs.create_instance "/pkg/ant.resources.binary/meshes/up_box.glb|mesh.prefab"
    -- function pp.on_ready(e)
    --     local ee<close> = w:entity(e.root)
    --     iom.set_scale(ee, 2.5)
    -- end
    -- world:create_object(pp)
    -- local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
    -- p.on_ready = function (e)
    --     local ee<close> = w:entity(e.root)
    --     iom.set_position(ee, math3d.vector(0, 5, 0, 1))
    -- end
    -- world:create_object(p)

    -- local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/headquater.glb|mesh.prefab"
    -- p.on_ready = function (e)
    --     local ee<close> = w:entity(e.root)
    --     iom.set_scale(ee, 0.1)
    -- end
    -- world:create_object(p)

    --cp_eid = color_palette_test()

    quad_eid = ientity.create_quad_lines_entity("quads", {r=math3d.quaternion{0.0, math.pi*0.5, 0.0}}, 
        "/pkg/ant.test.features/assets/quad.material", 10, 1.0)

    -- create_texture_plane_entity(
    --     {1, 1.0, 1.0, 1.0}, 
    --     "/pkg/ant.resources/textures/texture_plane.texture",
    --     {x=64, y=0, w=64, h=64}, {w=384, h=64})

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/world_simple.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         local ee<close> = w:entity(e.root)
    --         iom.set_scale(ee, 0.1)
    --     end
    --     world:create_object(p)
    -- end

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/plane.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         local ee<close> = w:entity(e.root)
    --         iom.set_scale(ee, 0.1)
    --         local ivav = ecs.import.interface "ant.test.features|ivertex_attrib_visualizer"

    --         local dl = w:first("directional_light scene:in")
    --         local d = math3d.inverse(math3d.todirection(dl.scene.r))
    --         for _, eid in ipairs(e.tag["*"]) do
    --             local ee<close> = w:entity(eid)
    --             ivav.display_normal(ee, d)
    --         end
            
    --     end
    --     world:create_object(p)
    -- end

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/world_simple.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         local ee<close> = w:entity(e.root)
    --         iom.set_scale(ee, 0.1)
    --         -- local ivav = ecs.import.interface "ant.test.features|ivertex_attrib_visualizer"

    --         -- local dl = w:first("directional_light scene:in")
    --         -- local d = math3d.inverse(math3d.todirection(dl.scene.r))
    --         -- for _, eid in ipairs(e.tag["*"]) do
    --         --     local ee<close> = w:entity(eid)
    --         --     ivav.display_normal(ee, d)
    --         -- end
            
    --     end
    --     world:create_object(p)
    -- end

    --ientity.create_grid_entity_simple "grid"

    -- ecs.create_entity{
	-- 	policy = {
	-- 		"ant.render|simplerender",
	-- 		"ant.general|name",
	-- 	},
	-- 	data = {
	-- 		scene 		= {
    --             srt = {
    --                 s = {50, 1, 50, 0}
    --             }
    --         },
	-- 		material 	= "/pkg/ant.resources/materials/singlecolor1.material",
	-- 		visible_state= "main_view",
	-- 		name 		= "test_shadow_plane",
	-- 		simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
	-- 		on_ready = function (e)
	-- 			imaterial.set_property(e, "u_basecolor_factor", {0.5, 0.5, 0.5, 1})
	-- 		end,
	-- 	}
    -- }
    --ientity.create_procedural_sky()
    --local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/headquater.glb|mesh.prefab"
    local g1 = ecs.group(1)
    local group_root = g1:create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.general|name",
        },
        data = {
            scene = {},
            on_ready = function (e)
                iom.set_position(e, math3d.vector(-20, 0, 0))
            end,
            name = "test_group",
        },
    }
    g1:create_entity{
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/lambert1.001.material",
            visible_state = "main_view",
            scene = {
                parent = group_root,
            },
            on_ready = function (e)
                iom.set_scale(e, 10)
            end,
            name = "test_group",
        },
    }

    ecs.create_instance"/pkg/ant.test.features/assets/entities/skybox_test.prefab"
    local p = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"
    p.on_ready = function (e)
        local pid = e.tag["*"][1]

        ecs.create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                simplemesh = ientity.arrow_mesh(0.3),
                material = "/pkg/ant.resources/materials/meshcolor.material",
                visible_state = "main_view",
                scene = {
                    parent = pid
                },
                name = "arrow",
                on_ready = function (ee)
                    imaterial.set_property(ee, "u_color", math3d.vector(1.0, 0.0, 0.0, 1.0))
                end
            }
        }
    end
    world:create_object(p)

    do
        testprefab = ecs.create_instance "/pkg/ant.test.features/assets/glb/headquater-1.glb|mesh.prefab"
        function testprefab.on_ready(e)
            local t = assetmgr.resource "/pkg/ant.test.features/assets/textures/headquater_basecolor_red.texture"
            local mesh_eid = e.tag["*"][2]
            local te<close> = w:entity(mesh_eid)
            imaterial.set_property(te, "s_basecolor", t.id)
            iom.set_scale(te, 0.1)
        end
        world:create_object(testprefab)
    end

    -- do
    --     ecs.create_instance "/pkg/ant.test.features/assets/glb/electric-pole-1.glb|mesh.prefab"
    -- end


    local off = 0.1
	ientity.create_screen_axis_entity("global_axes", {type = "percent", screen_pos = {off, 1-off}}, {s=0.1})
    --ecs.create_instance "/pkg/ant.test.features/assets/glb/logistics_center.glb|mesh.prefab"

    -- local p = ecs.create_instance "/pkg/ant.test.features/assets/entities/cube.prefab"
    -- function p:on_ready()
    --     local e = self.tag.cube[1]
    --     e.render_object.material.u_color = math3d.vector(0.8, 0, 0.8, 1.0)
    -- end

    --world:create_object(p)
    --print(p)
    --ecs.create_instance  "/pkg/ant.test.features/assets/entities/test_scene.prefab"
    --ecs.create_instance  "/pkg/ant.test.features/assets/entities/skybox_test.prefab"
    --ecs.create_instance  "/pkg/ant.test.features/assets/glb/cloud.glb|mesh.prefab"
    --ecs.create_instance  "/pkg/ant.test.features/assets/glb/shadow.glb|mesh.prefab"
    -- local p = ecs.create_instance  "/pkg/ant.test.features/assets/glb/Fox.glb|mesh.prefab"
    -- foxeid = p[3]
    
    --ecs.create_instance  "/pkg/ant.test.features/assets/glb/shuijing.glb|mesh.prefab"
    --ecs.create_instance  "/pkg/ant.resources/meshes/SimpleSkin/SimpleSkin.glb|mesh.prefab"
    -- ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_point.prefab"
    -- local eid = ecs.create_instance  "/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab"[1]
    -- world:pub{"after_init", eid}
    --ecs.create_instance  "/pkg/ant.test.features/assets/entities/font_tt.prefab"
    --ecs.create_instance  "/pkg/ant.resources.binary/meshes/female/female.glb|mesh.prefab"

    --ientity.create_procedural_sky()
    --target_lock_test()

    --ientity.create_skybox()
    --ecs.create_instance  "/pkg/ant.test.features/assets/glb/Duck.glb|mesh.prefab"

    --ecs.create_instance  "/pkg/ant.resources.binary/meshes/cloud_run.glb|mesh.prefab"
    --ecs.create_instance  "/pkg/ant.test.features/assets/CloudTestRun.glb|mesh.prefab"

    -- local eid = world:deprecated_create_entity {
    --     policy = {
    --         "ant.general|name",
    --         "ant.render|render",
    --         "ant.scene|transform_policy",
    --     },
    --     data = {
    --         name = "collider",
    --         scene_entity = true,
    --         sceme = {srt={s=100}},
    --         filterstate = "main_view|selectable",
    --         material = "/pkg/ant.resources/materials/singlecolor.material",
    --         mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
    --     }
    -- }

    local pp = ecs.create_instance "/pkg/ant.test.features/assets/glb/miner-1.glb|mesh.prefab"
    pp.on_ready = function (e)
        local ee<close> = w:entity(e.tag['*'][1])
        iom.set_scale(ee, 0.1)
    end

    world:create_object(pp)
end

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
    
end

local kb_mb = world:sub{"keyboard"}

local mouse_mb = world:sub{"mouse", "LEFT"}

local enable = 1
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
        end
    end


end

function init_loader_sys:camera_usage()
    for _, _, state, x, y in mouse_mb:unpack() do
        local mq = w:first("main_queue render_target:in camera_ref:in")
        local ce = w:entity(mq.camera_ref, "camera:in")
        local camera = ce.camera
        local vpmat = camera.viewprojmat
    
        local vr = mq.render_target.view_rect
        local nx, ny = mu.remap_xy(x, y, vr.ratio)
        local ndcpt = mu.pt2D_to_NDC({nx, ny}, vr)
        ndcpt[3] = 0
        local p0 = mu.ndc_to_world(vpmat, ndcpt)
        ndcpt[3] = 1
        local p1 = mu.ndc_to_world(vpmat, ndcpt)
    
        local ray = {o = p0, d = math3d.sub(p0, p1)}
    
        local plane = math3d.vector(0, 1, 0, 0)
        local r = math3d.muladd(ray.d, math3d.plane_ray(ray.o, ray.d, plane), ray.o)
        
        print("click:", x, y, math3d.tostring(r), "view_rect:", vr.x, vr.y, vr.w, vr.h)
    end
end
