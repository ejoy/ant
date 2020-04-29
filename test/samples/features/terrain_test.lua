local ecs = ...
local world = ecs.world

local utilitypkg= import_package "ant.utility"
local fs_rt = utilitypkg.fs_rt
local fs = require "filesystem"

local math3d = require "math3d"

local terrain_test_sys = ecs.system "terrain_test_system"

local icollider = world:interface "ant.collision|collider"

function terrain_test_sys:init()
	world:create_entity(fs_rt.read_file(fs.path "/pkg/ant.test.features/assets/entities/terrain.txt"))
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