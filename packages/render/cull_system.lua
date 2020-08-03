--luacheck: ignore self
local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local cull_sys = ecs.system "cull_system"

function cull_sys:cull()
	for _, eid in world:each "primitive_filter" do
		local e = world[eid]
		local filter = e.primitive_filter

		if e.visible then
			local vp = world[e.camera_eid]._rendercache.viewprojmat
			local frustum_planes = math3d.frustum_planes(vp)

			local results = filter.result
			for _, resulttarget in pairs(results) do
				if resulttarget.needcull then
					resulttarget.visible_set = math3d.frustum_intersect_aabb_list(frustum_planes, resulttarget.items)
				else
					resulttarget.visible_set = resulttarget.items
				end
			end
		end
	end
end