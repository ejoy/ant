local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local cu = renderpkg.components
local st_sys = ecs.system "shadow_test_system"

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

function st_sys:init()
    cu.create_plane_entity(
		world,
		{srt = {s ={50, 1, 50, 0}}},
		"/pkg/ant.resources/materials/test/mesh_shadow.material",
		{0.8, 0.8, 0.8, 1},
		"test shadow plane"
	)
end

local function directional_light_arrow_widget(srt, cylinder_cone_ratio, cylinder_rawradius)
	--[[
		cylinde & cone
		1. center in (0, 0, 0, 1)
		2. size is 2
		3. pointer to (0, 1, 0)

		we need to:
		1. rotate arrow, make it rotate to (0, 0, 1)
		2. scale cylinder as it match cylinder_cone_ratio
		3. scale cylinder radius
	]]

	 local local_rotator = math3d.quaternion{math.rad(-90), 0, 0}
	 srt.r = math3d.tovalue(srt.r and math3d.mul(math3d.quaternion(srt.r), local_rotator) or local_rotator)

	local arroweid = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {
				srt = srt,
			},
			name = "directional light arrow",
		},
	}

	local cone_rawlen<const> = 2
	local cone_raw_halflen = cone_rawlen * 0.5
	local cylinder_rawlen = cone_rawlen
	local cylinder_len = cone_rawlen * cylinder_cone_ratio
	local cylinder_halflen = cylinder_len * 0.5
	local cylinder_scaleY = cylinder_len / cylinder_rawlen

	local cylinder_radius = cylinder_rawradius or 0.65

	local cone_raw_centerpos = mc.ZERO_PT
	local cone_centerpos = math3d.add(math3d.add({0, cylinder_halflen, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})

	local cylinder_bottom_pos = math3d.vector(0, -cylinder_halflen, 0, 1)
	local cone_top_pos = math3d.add(cone_centerpos, {0, cone_raw_halflen, 0, 1})

	local arrow_center = math3d.mul(0.5, math3d.add(cylinder_bottom_pos, cone_top_pos))

	local cylinder_raw_centerpos = mc.ZERO_PT
	local cylinder_offset = math3d.sub(cylinder_raw_centerpos, arrow_center)

	local cone_offset = math3d.sub(cone_centerpos, arrow_center)

	world:create_entity{
		policy = {
			"ant.render|mesh",
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			can_render = true,
			transform = {
				srt = {
					s = {cylinder_radius, cylinder_scaleY, cylinder_radius},
					t = math3d.tovalue(cylinder_offset),
				}
			},
			material = [[
---
/pkg/ant.resources/materials/singlecolor.material
---
op:replace
path:/properties/uniforms/u_color
value:
  type:v4
  value:
    {1, 0, 0, 1}
]],
			mesh = '/pkg/ant.resources/meshes/cylinder.mesh',
			parent = arroweid,
			name = "arrow.cylinder",
			rendermesh = {},
		}
	}

	world:create_entity{
		policy = {
			"ant.render|mesh",
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			can_render = true,
			rendermesh = {},
			transform = {
				srt = {
					t = math3d.tovalue(cone_offset)
				}
			},
			material = [[
---
/pkg/ant.resources/materials/singlecolor.material
---
op:replace
path:/properties/uniforms/u_color
value:
  type:v4
  value:
    {1, 0, 0, 1}
]],
			mesh = '/pkg/ant.resources/meshes/cone.mesh',
			parent = arroweid,
			name = "arrow.cone"
		}
	}
end

function st_sys:post_init()
    local dl = world:singleton_entity "directional_light"
	local rotator = math3d.torotation(math3d.inverse(dl.direction))
    local pos = math3d.tovalue(dl.position)
    directional_light_arrow_widget({s = {0.02}, r = math3d.tovalue(rotator), t = pos}, 8, 0.45)
end