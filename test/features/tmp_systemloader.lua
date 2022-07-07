local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local ientity = ecs.import.interface "ant.render|ientity"
local ies = ecs.import.interface "ant.scene|ifilter_state"
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
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name = "test_texture_plane",
            simplemesh = imesh.init_mesh(ientity.plane_mesh(mu.texture_uv(tex_rect, tex_size))),
            owned_mesh_buffer = true,
            material = "/pkg/ant.resources/materials/texture_plane.material",
            filter_state= "main_view",
            scene   = { srt = {t={0, 5, 5}}},
            on_ready = function (e)
                w:sync("render_object:in", e)
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
                    {
                        handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {
                            0.0, 0.0, 0.0, 
                            0.0, 0.0, 1.0,
                            1.0, 0.0, 0.0,
                        }), declmgr.get "p3".handle)
                    }
                }
            },
            material = "/pkg/ant.resources/materials/color_palette_test.material",
            filter_state = "main_view",
            scene = {srt={}},
            name = "color_pal_test",
        }
    }
end

local cp_eid, quad_eid

local after_init_mb = world:sub{"after_init"}
function init_loader_sys:init()
    --point_light_test()
    --ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)

    -- local pp = ecs.create_instance "/pkg/ant.resources.binary/meshes/up_box.glb|mesh.prefab"
    -- function pp.on_ready(e)
    --     iom.set_scale(world:entity(e.root), 2.5)
    -- end
    -- world:create_object(pp)
    -- local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
    -- p.on_ready = function (e)
    --     iom.set_position(world:entity(e.root), {0, 5, 0})
    -- end
    -- world:create_object(p)

    -- local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/headquater.glb|mesh.prefab"
    -- p.on_ready = function (e)
    --     iom.set_scale(world:entity(e.root), 0.1)
    -- end
    -- world:create_object(p)

    --cp_eid = color_palette_test()

    -- quad_eid = ientity.create_quad_lines_entity("quads", {r=math3d.quaternion{0.0, math.pi*0.5, 0.0}}, 
    --     "/pkg/ant.test.features/assets/quad.material", 10, 1.0)

    -- create_texture_plane_entity(
    --     {1, 1.0, 1.0, 1.0}, 
    --     "/pkg/ant.resources/textures/texture_plane.texture",
    --     {x=64, y=0, w=64, h=64}, {w=384, h=64})

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/world_simple.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         iom.set_scale(world:entity(e.root), 0.1)
    --     end
    --     world:create_object(p)
    -- end

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/plane.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         iom.set_scale(world:entity(e.root), 0.1)
    --         local ivav = ecs.import.interface "ant.test.features|ivertex_attrib_visualizer"

    --         local dl = w:singleton("directional_light", "scene:in")
    --         local d = math3d.inverse(math3d.todirection(dl.scene.r))
    --         for _, ee in ipairs(e.tag["*"]) do
    --             ivav.display_normal(world:entity(ee), d)
    --         end
            
    --     end
    --     world:create_object(p)
    -- end

    -- do
    --     local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/world_simple.glb|mesh.prefab"
    --     p.on_ready = function (e)
    --         iom.set_scale(world:entity(e.root), 0.1)
    --         -- local ivav = ecs.import.interface "ant.test.features|ivertex_attrib_visualizer"

    --         -- local dl = w:singleton("directional_light", "scene:in")
    --         -- local d = math3d.inverse(math3d.todirection(dl.scene.r))
    --         -- for _, ee in ipairs(e.tag["*"]) do
    --         --     ivav.display_normal(world:entity(ee), d)
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
	-- 		filter_state= "main_view",
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
                w:sync("scene:in id:in", e)
                iom.set_position(e, math3d.vector(-20, 0, 0))
                w:sync("scene:out", e)
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
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/lambert1.001.material",
            filter_state = "main_view",
            scene = {
                parent = group_root,
            },
            on_ready = function (e)
                w:sync("scene:in id:in", e)
                iom.set_scale(e, 10)
                w:sync("scene:out", e)
            end,
            name = "test_group",
        },
    }

    ecs.create_instance"/pkg/ant.test.features/assets/entities/skybox_test.prefab"
    local p = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"
    p.on_ready = function (e)
        local a_eid = ientity.create_arrow_entity({}, 0.3, math3d.vector(1.0, 0.0, 0.0, 1.0), "/pkg/ant.resources/materials/meshcolor.material")
        ecs.method.set_parent(a_eid, e.tag["*"][1])
    end
    world:create_object(p)
    -- local p = ecs.create_instance "/pkg/ant.resources.binary/meshes/offshore-pump.glb|mesh.prefab"
    -- function p.on_ready()
    --     iom.set_position(p.root, {3, 0.0, 0.0})
    -- end
    -- -- p.on_ready = function (e)
    -- --     for _, ee in ipairs(e.tag['*']) do
    -- --         ies.set_state(ee, "main_view", false)
    -- --         ies.set_state(ee, "cast_shadow", false)
    -- --     end
    -- -- end
    -- -- p.on_update = function(e)
    -- --     for _, ee in ipairs(e.tag['*']) do
    -- --         w:sync("skeleton?in", ee)
    -- --         if ee.skeleton then
    -- --             --w:sync("pose_result:in", ee)
    -- --             local iwd = ecs.import.interface "ant.render|iwidget_drawer"
    -- --             iwd.draw_skeleton(ee.skeleton._handle, ee.pose_result, math3d.matrix{s={1.0, 1.0, -1.0}}, 0xff00ffff)
    -- --             break
    -- --         end
    -- --     end
    -- -- end
    -- world:create_object(p)

    local off = 0.1
	ientity.create_screen_axis_entity({s=0.1}, {type = "percent", screen_pos = {off, 1-off}}, "global_axes")

    -- local p = ecs.create_instance "/pkg/ant.test.features/assets/entities/cube.prefab"
    -- function p:on_ready()
    --     local e = self.tag.cube[1]
    --     w:sync("render_object:in", e)
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
    --         mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
    --     }
    -- }
end

function init_loader_sys:init_world()
    for msg in after_init_mb:each() do
        local e = msg[2]
        local s = iom.get_scale(e)
        iom.set_scale(e, math3d.mul(s, {5, 5, 5, 0}))
    end

    local mq = w:singleton("main_queue", "camera_ref:in")
    local eyepos = math3d.vector(8, 8, 0)
    local camera_ref = world:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)
    
end

local kb_mb = world:sub{"keyboard"}

local enable = 1
function init_loader_sys:entity_init()
    
    for _, key, press in kb_mb:unpack() do
        if key == "SPACE" and press == 0 then
            -- local icw = ecs.import.interface "ant.render|icurve_world"
            -- icw.enable(not icw.param().enable)

            --imaterial.set_color_palette("default", 0, math3d.vector(1.0, 0.0, 1.0, 0.0))

            -- local e = world:entity(quad_eid)
            -- ies.set_state(e, "main_view", true)
            -- local ib = e.render_object.ib
            -- local quad_2 = 2
            -- ib.num = quad_2 * 6
            
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
            local d = w:singleton("directional_light", "scene:in id:in")
            iom.set_position(d, {0, 1, 0})
        end
    end
end
