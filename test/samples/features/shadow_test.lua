local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local cu = renderpkg.components
local st_sys = ecs.system "shadow_test_system"

function st_sys:init()
    cu.create_plane_entity(
		world,
		{srt = {s ={50, 1, 50, 0}}},
		"/pkg/ant.resources/materials/test/mesh_shadow.material",
		{0.8, 0.8, 0.8, 1},
		"test shadow plane"
	)
end

local function directional_light_arrow_widget(srt)
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
					t = {0, 0.5, 0, 1},
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
					t = {0, 1.5, 0, 1},
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
    directional_light_arrow_widget({r = math3d.tovalue(rotator), t = pos})
end