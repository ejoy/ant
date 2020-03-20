local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local animodule = require "hierarchy.animation"

ecs.component_alias("attach", "entityid")

ecs.component "hierarchy_transform_result" {}
ecs.singleton "hierarchy_transform_result" {}

local scene_space = ecs.system "scene_space"

scene_space.require_system "primitive_filter_system"
scene_space.require_singleton "hierarchy_transform_result"

local pseudoroot_eid = -1

local mark_mt = { 
	__index = function(marked, eid) 
		if eid == pseudoroot_eid then
			marked[pseudoroot_eid] = false
			return false
		end
		local e = world[eid]
		if e then
			local pid = e.transform.parent
			if pid and marked[pid] then
				marked[eid] = pid
				return true
			end
		end

		marked[eid] = false
		return false
	end 
}

-- local render_mark_mt = {
-- 	__index = function(marked, eid) 
-- 		if eid == pseudoroot_eid then
-- 			marked[pseudoroot_eid] = false
-- 			return false
-- 		end
-- 		local e = world[eid]
-- 		if e.hierarchy == nil then
-- 			local pid = e.transform.parent
-- 			if pid and marked[pid] then
-- 				marked[eid] = pid
-- 				return true
-- 			end
-- 		end

-- 		marked[eid] = false
-- 		return false
-- 	end
-- }

local function mark_tree(tree, componenttype)
	for _, eid in world:each(componenttype) do
		assert(world[eid].transform)
		local _ = tree[eid]
	end
end

local update_follow_mb = world:sub {"update_follow"}
local function mark_follow_mb(tree)
	for _,_,follow_by in update_follow_mb:unpack() do
		assert(world[follow_by].transform)
		local _ = tree[follow_by]
	end
end

local function tree_sort(tree)
	local r = {}

	local from = 1
	local to = 1
	-- find leaves
	local leaf = {}
	for eid, pid in pairs(tree) do
		if pid then
			if leaf[pid] then	-- fake leaf
				-- todo remove result
				for i = 1, to-1 do
					if r[i] == pid then
						to = to - 1
						r[i] = r[to]
						break
					end
				end
			end
			leaf[pid] = false
			if leaf[eid] == nil then
				leaf[eid] = true	-- mark leaf
				r[to] = eid
				to = to + 1
			end
		end
	end
	while to > from do
		local lb = from
		from = to
		for i = lb, to-1 do
			local pid = tree[r[i]]
			if pid and tree[pid] and not leaf[pid] then
				r[to] = pid
				to = to + 1
				leaf[pid] = true
			end
		end
	end
	return r
end

local function update_hirarchy_entity_world(trans)
	local srt = trans.srt
	local peid = trans.parent
	if peid and world[peid] then
		local parent = world[peid]
		local pt = parent.transform

		local worldmat = trans.world
		worldmat.m = math3d.mul(pt.srt, srt)
		return worldmat
	end
	return srt
end

local function fetch_sort_tree_result(tree, componenttype)
	setmetatable(tree, mark_mt)
	mark_tree(tree, componenttype)
	mark_follow_mb(tree)
	return tree_sort(tree)
end

local function fetch_hirarchy_tree(tree)
	return fetch_sort_tree_result(tree, "hierarchy")
end

local function mark_cache(eid, cache_result)
	local e = world[eid]
	local t = e.transform
	
	local cachemat = update_hirarchy_entity_world(t)
	assert(type(cachemat) == 'userdata')

	local hiecomp = e.hierarchy
	if hiecomp and hiecomp.ref_path then
		local hiehandle = assetmgr.get_resource(hiecomp.ref_path).handle
		if t.hierarchy_result == nil then
			local bpresult = animodule.new_bind_pose(#hiehandle)
			hiehandle:bind_pose(bpresult)
			t.hierarchy_result = setmetatable({}, {__index=function(t, key)
				local jointidx = hiehandle:joint_index(key)
				local j = bpresult:joint(jointidx)
				t[key] = j
				return j
			end})
		end
	end
	cache_result[eid] = {world=cachemat, hierarchy=t.hierarchy_result}
end

local function update_hierarchy_tree(tree, cache_result)
	local sort_result = fetch_hirarchy_tree(tree)
	log.info_a("sort_result",sort_result)
	for i = #sort_result, 1, -1 do
		local eid = sort_result[i]
		mark_cache(eid, cache_result)
	end
end

local function update_remove_subtree(remove_trees, cache_result)
	-- move removed hirarchy entity transform to children
	local hierarchy_trees = {}
	for _, subtree in pairs(remove_trees) do
		for _, subeid in ipairs(subtree) do
			local subentity = assert(world[subeid])
			if subentity.hierarchy then
				hierarchy_trees[subeid] = pseudoroot_eid
			end
		end
	end

	if next(hierarchy_trees) then
		update_hierarchy_tree(hierarchy_trees, cache_result)
	end
end

local hie_del_mb = world:sub {"hierarchy_delete"}

local function hierarchy_del_handle(hierarchy_cache)
	local removed_eids = {}
	for _, eid in hie_del_mb:unpack() do
		hierarchy_cache[eid] = nil
		removed_eids[eid] = true
	end

	if next(removed_eids) then
		local trees = {}
		for _, eid in world:each "transform" do
			assert(removed_eids[eid] == nil)

			local e = world[eid]
			local trans = e.transform
			local peid = trans.parent
			if removed_eids[peid] then
				e.transform.parent = nil
				local subtree = trees[peid]
				if subtree == nil then
					subtree = {}
					trees[peid] = subtree
				end
				subtree[#subtree+1] = eid
			end
		end

		update_remove_subtree(trees, hierarchy_cache)
	end
end

local function parent_changed(eid, oldparent, trees)
	local newparent = world[eid].transform.parent
	if newparent and world[newparent] then
		if newparent ~= oldparent then
			local parentparent = world[newparent].transform.parent
			trees[newparent] = parentparent
		end

		trees[eid] = newparent or pseudoroot_eid
	else
		trees[eid] = pseudoroot_eid
	end
end

local trans_changed_mb = world:sub {"component_changed", "transform"}

local register_remove_mb = {
	world:sub {"component_register", "hierarchy"},
}

local function get_check_mb_list()
	local list = {}
	for _, mb in ipairs(register_remove_mb) do
		list[#list+1] = mb
	end
	return list
end

local checklist = get_check_mb_list()
local begin_follow_mb = world:sub {"update_follow"}

function scene_space:scene_update()
	local trees = {}

	local function mark_parent(eid)
		trees[eid] = world[eid].transform.parent or pseudoroot_eid
	end

	for _,follower,followby,old_followby in begin_follow_mb:unpack() do
		parent_changed(follower,old_followby,trees)
		mark_parent(followby)
	end

	for event in trans_changed_mb:each() do
		local eid = event[3]
		local e = world[eid]

		local what = event[4]
		if e.hierarchy then
			if what.field == "parent" then
				local oldparent = what.oldvalue
				parent_changed(eid, oldparent, trees)
			end

			mark_parent(eid)
		end
	end
	
	for _, mb in ipairs(checklist) do
		for msg in mb:each() do
			local eid = msg[3]
			if world[eid] then
				mark_parent(msg[3])
			end
		end
	end

	local transform_result = world:singleton "hierarchy_transform_result"
	if next(trees) then
		update_hierarchy_tree(trees, transform_result)
	end

	hierarchy_del_handle(transform_result)
end
