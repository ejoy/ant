local ecs = ...
local world = ecs.world

local serialize = import_package "ant.serialize"

local math3d = require "math3d"

local terrain_test_sys = ecs.system "terrain_test_system"

local icollider = world:interface "ant.collision|collider"

function terrain_test_sys:init()
	world:create_entity {
		policy = {
			"ant.render|render",
			"ant.terrain|terrain_policy",
			"ant.general|name",
			"ant.collision|terrain_collider_policy",
			"ant.serialize|serialize",
		},
		data = {
			rendermesh = {},
			material = "/pkg/ant.resources/terrain/test.material",
			transform = {srt = {}},
			can_render = true,
			terrain = {
				tile_width = 2,
				tile_height = 2,
				section_size = 2,
				element_size = 7,
			},
			collider = {
				terrain = {
					{
						origin = {0, 0, 0, 1},
					}
				}
			},
			scene_entity = true,
			name = "terrain_test_sys",
			serialize = serialize.create(),
		}
	}

	local p2, p1 = math3d.vector(0, 1, 0, 1), math3d.vector(0, -1, 0, 1)
	local hitpt, hitnormal, id = icollider.raycast {p1, p2}
	if hitpt then
		print("raycast terrain collider:")
		print("\thitpt:", math3d.tostring(hitpt))
		print("\thitnormal:", math3d.tostring(hitnormal))
		local eid = icollider.which_entity(id)
		print("\tbody id:", id)
		if eid then
			print("\tentity:", eid, world[eid].name or "")
		end
	else
		print("not found hit point to terrain collider")
	end
end