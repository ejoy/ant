local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local terrain_test_sys = ecs.system "terrain_test_system"

local icollider = ecs.import.interface "ant.collision|collider"

function terrain_test_sys:init()
	world:instance("/pkg/ant.test.features/assets/entities/terrain.prefab")
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