local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local computil = world:interface "ant.render|entity"
local st_sys = ecs.system "shadow_test_system"

local mc = import_package "ant.math".constant
local ies = world:interface "ant.scene|ientity_state"
local imaterial = world:interface "ant.asset|imaterial"
local ilight = world:interface "ant.render|light"
local iom = world:interface "ant.objcontroller|obj_motion"

function st_sys:init()
	world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|shadow_cast_policy",
			"ant.general|name",
		},
		data = {
			state = ies.create_state "visible|selectable|cast_shadow",
			scene_entity = true,
			transform =  {
				s=100,
				t={0, 2, 0, 0}
			},
			material = "/pkg/ant.resources/materials/bunny.material",
			mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "cast_shadow_cube",
		}
	}

	local rooteid = world:create_entity {
		policy = {
			"ant.scene|transform_policy",
			"ant.general|name",
		},
		data = {
			transform =  {t = {0, 0, 3, 1}},
			name = "mesh_root",
			scene_entity = true,
		}
	}
	world:instance("/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab", {import={root=rooteid}})

    local eid = computil.create_plane_entity(
		{t = {0, 0, 0, 1}, s = {50, 1, 50, 0}},
		"/pkg/ant.resources/materials/mesh_shadow.material",
		"test shadow plane")

	imaterial.set_property(eid, "u_basecolor_factor", {0.8, 0.8, 0.8, 1})
end

function st_sys:post_init()
	ilight.create_light_direction_arrow(ilight.directional_light(), {scale=0.02, cylinder_cone_ratio=1, cylinder_rawradius=0.45})
end
