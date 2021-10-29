local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"

local ientity = ecs.import.interface "ant.render|entity"
local ies = ecs.import.interface "ant.scene|ientity_state"
local init_loader_sys = ecs.system 'init_loader_system'
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh = ecs.import.interface "ant.asset|imesh"

local mathpkg = import_package"ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local camerapkg = import_package"ant.camera"
local split_frustum = camerapkg.split_frustum

local icamera = ecs.import.interface "ant.camera|camera"
local iom = ecs.import.interface "ant.objcontroller|obj_motion"

local function find_entity(name, whichtype)
    for _, eid in world:each(whichtype) do
        if world[eid].name:match(name) then
            return eid
        end
    end
end

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

    local  lighteid = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
    iom.set_position(lighteid, {0, 1, 0, 1})

    -- for _, p in ipairs(pl_pos) do
    --     local  lighteid = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
    --     iom.set_position(lighteid, p)
    -- end

    -- local cubeeid = ecs.create_instance  "/pkg/ant.test.features/assets/entities/pbr_cube.prefab"[1]
    -- iom.set_position(cubeeid, {0, 0, 0, 1})

    local eid = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"[1]

    -- for _, r in ipairs{
    --     math3d.quaternion{2.4, 0, 0},
    --     math3d.quaternion{-2.4, 0, 0},
    --     math3d.quaternion{0, 1, 0},
    -- } do
    --     local eid = ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"[1]
    --     iom.set_rotation(eid, r)
    -- end
end

local icc = ecs.import.interface "ant.test.features|icamera_controller"
local after_init_mb = world:sub{"after_init"}
function init_loader_sys:init()
    --point_light_test()
    --ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
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
	-- 		state 		= "visible",
	-- 		name 		= "test_shadow_plane",
	-- 		simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
	-- 		on_ready = function (e)
	-- 			imaterial.set_property(e, "u_basecolor_factor", {0.5, 0.5, 0.5, 1})
	-- 		end,
	-- 	}
    -- }
    --ientity.create_procedural_sky()
    ecs.create_instance "/pkg/ant.test.features/assets/entities/skybox_test.prefab"
    ecs.create_instance  "/pkg/ant.test.features/assets/entities/light_directional.prefab"

    -- local p = ecs.create_instance "/pkg/ant.test.features/assets/entities/cube.prefab"
    -- function p:on_ready()
    --     local e = self.tag.cube[1]
    --     w:sync("render_object:in", e)
    --     imaterial.set_property_directly(e.render_object.properties, "u_color", {0.8, 0, 0.8, 1.0})
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
    --         transform = {s=100},
    --         --color = {1.0, 0.5, 0.5, 0.5},
    --         state = ies.create_state "visible|selectable",
    --         material = "/pkg/ant.resources/materials/singlecolor.material",
    --         mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
    --     }
    -- }
end

local function main_camera_ref()
    for e in w:select "main_queue camera_ref:in" do
        return e.camera_ref
    end
end

function init_loader_sys:init_world()
    for msg in after_init_mb:each() do
        local eid = msg[2]
        local s = iom.get_scale(eid)
        iom.set_scale(eid, math3d.mul(s, {5, 5, 5, 0}))
    end

    local mq = w:singleton("main_queue", "camera_ref:in")
    local eyepos = math3d.vector(0, 8, -8)
    local camera_ref = mq.camera_ref
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)
    
end

function init_loader_sys:entity_init()

end
