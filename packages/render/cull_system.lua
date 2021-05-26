--luacheck: ignore self
local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local icp = ecs.interface "icull_primitive"
function icp.cull(filter, vp_mat)
	local frustum_planes = math3d.frustum_planes(vp_mat)
	local results = filter.result
	for _, resulttarget in pairs(results) do
		local vs = resulttarget.visible_set
		if vs then
			local items = resulttarget.items
			if #items > 0 then
				vs.n = math3d.frustum_intersect_aabb_list(frustum_planes, items, vs)
			else
				vs.n = 0
			end
		end
	end
end

local cull_sys = ecs.system "cull_system"

function cull_sys:cull()
	for _, eid in world:each "primitive_filter" do
		local e = world[eid]
		if e.visible then
			local filter = e.primitive_filter
			local vp = world[e.camera_eid]._rendercache.viewprojmat
			icp.cull(filter, vp)
		end
	end
end