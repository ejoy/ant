local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local serialize = import_package "ant.serialize"

local mathpkg = import_package "ant.math"
local mu, ms, mc = mathpkg.util, mathpkg.stack, mathpkg.constant

local terrain_test = ecs.system "terrain_test"
terrain_test.require_system 'init_loader'

terrain_test.require_policy "ant.terrain|terrain_render"
terrain_test.require_policy "ant.collision|terrain_collider"

terrain_test.require_interface "ant.collision|collider"

local icollider = world:interface "ant.collision|collider"

function terrain_test:init()
	world:create_entity {
		policy = {
			"ant.render|render",
			"ant.terrain|terrain_render",
			"ant.render|name",
			"ant.collision|terrain_collider",
			"ant.serialize|serialize",
		},
		data = {
			rendermesh = {},
			material = {
				ref_path = fs.path "/pkg/ant.resources/depiction/terrain/test.material",
			},
			transform = mu.srt(),
			can_render = true,
			terrain = {
				tile_width = 2,
				tile_height = 2,
				section_size = 2,
				element_size = 7,
			},
			terrain_collider = {
				shape = {
					origin = {0, 0, 0, 1},
				}
			},
			name = "terrain_test",
			serialize = serialize.create(),
		}
	}

	local p1, p2 = ms({0, 1, 0, 1}, {0, -1, 0, 1}, "PP")
	local hitpt, hitnormal = icollider.raycast {p1, p2}
	if hitpt then
		print("raycast terrain collider:")
		print("\thitpt:", ms(hitpt, "V"))
		print("\thitnormal:", ms(hitnormal, "V"))
	else
		print("not found hit point to terrain collider")
	end
end