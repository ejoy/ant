local ecs = ...
local world = ecs.world

local animoudle = require "hierarchy.animation"

local pf = ecs.component "primitive_filter"

function pf:init()
	self.result = {
		translucent = {
			visible_set = {},
		},
		opaticy = {
			visible_set = {},
		},
	}
	return self
end

local prim_filter_sys = ecs.system "primitive_filter_system"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.n = 0
	end
end

local function add_result(eid, group, materialinfo, trans, result)
	local idx = result.n + 1
	local r = result[idx]
	if r == nil then
		r = {
			mgroup 		= group,
			material 	= assert(materialinfo),
			transform 	= trans,
			aabb		= trans._aabb,
			eid 		= eid,
		}
		result[idx] = r
	else
		r.mgroup 	= group
		r.material 	= assert(materialinfo)
		r.transform	= trans
		r.aabb		= trans._aabb
		r.eid 		= eid
	end
	result.n = idx
	return r
end

function prim_filter_sys:filter_primitive()
	for _, prim_eid in world:each "primitive_filter" do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		reset_results(filter.result)
		local filtertag = filter.filter_tag

		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			if ce[filtertag] then
				local primgroup = ce.rendermesh

				local m = ce.material
				local resulttarget = assert(filter.result[m.fx.surface_type.transparency])
				local trans = ce.transform
				local skinning = ce.skinning
				if skinning and skinning.type == "GPU" then
					local skin = primgroup.skin
					local sm = skinning.skinning_matrices
					animoudle.build_skinning_matrices(sm, ce.pose_result, skin.inverse_bind_pose, skin.joint_remap, trans._world)
					trans._skinning_matrices = sm
				end
				add_result(eid, primgroup, m, trans, resulttarget)
			end
		end
	end
end

