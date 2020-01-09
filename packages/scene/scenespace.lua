local ecs = ...
local world = ecs.world

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local animodule = require "hierarchy.animation"

ecs.component_alias("attach", "entityid")
ecs.component_alias("ignore_parent_scale", "boolean")

local ip = ecs.policy "ignore_parent_scale"
ip.require_component "ignore_parent_scale"

ecs.component "hierarchy_transform_result" {}
ecs.singleton "hierarchy_transform_result" {}

local scene_space = ecs.system "scene_space"

scene_space.require_system "primitive_filter_system"

scene_space.require_singleton "event"
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

local function update_hirarchy_entity_world(trans, ignore_parentscale)
	local srt = ms:srtmat(trans)
	local peid = trans.parent
	if peid and world[peid] then
		local parent = world[peid]
		local pt = parent.transform

		local finalmat = ms:mul_srtmat(pt.world, srt, ignore_parentscale)
		ms(trans.world, finalmat, "=")
	else
		ms(trans.world, srt, "=")
	end
	return trans.world
end

local function fetch_sort_tree_result(tree, componenttype)
	setmetatable(tree, mark_mt)
	mark_tree(tree, componenttype)
	return tree_sort(tree)
end

local function fetch_hirarchy_tree(tree)
	return fetch_sort_tree_result(tree, "hierarchy")
end

local function mark_cache(eid, cache_result)
	local e = world[eid]
	local t = e.transform
	
	local cachemat = update_hirarchy_entity_world(t, e.ignore_parent_scale)
	assert(type(cachemat) == 'userdata')

	local hiecomp = assert(e.hierarchy)
	if hiecomp.ref_path then
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
	if next(tree) then
		local sort_result = fetch_hirarchy_tree(tree)
		for i = #sort_result, 1, -1 do
			local eid = sort_result[i]
			mark_cache(eid, cache_result)
		end
	end
end

local function update_transform_field(trans, events, init)
	if init then
		assert(events == nil or (not next(events)))
		return true
	end

	local changed = true
	for k, v in pairs(events) do
		if k == 's' or k == 'r' or k == 't' then
			ms(trans[k], v, "=")
		elseif k == 'parent' then
			trans.parent = v
		else
			changed = changed or nil
		end
	end

	return changed
end

local function update_remove_subtree(remove_trees, cache_result)
	-- move removed hirarchy entity transform to children
	local hierarchy_trees = {}
	for _, subtree in pairs(remove_trees) do
		for _, subeid in ipairs(subtree) do
			local subentity = assert(world[subeid])

			local trans = subentity.transform
			trans.world(ms:srtmat(trans))
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

local function add_hierarchy_tree_item(eid, events, init, trees)
	local trans = world[eid].transform
	local oldparent = trans.parent
	if events then
		update_transform_field(trans, events, init)
	end

	local newparent = trans.parent
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

local trans_mb = world:sub {"component_register", "transform"}
local hierarchy_mb = world:sub {"component_register", "hierarchy"}
local ignore_parent_scale_mb = world:sub {"component_register", "ignore_parent_scale"}
local ignore_parent_scale_delete_mb = world:sub {"component_removed", "ignore_parent_scale"}
function scene_space:data_changed()
	for msg in trans_mb:each() do
		local eid = msg[3]
		world:singleton "event":new(eid, "transform")
	end
	
	local trees = {}
	
	for eid, events, init in world:singleton "event":each "transform" do
		local e = world[eid]
		if e.hierarchy then
			add_hierarchy_tree_item(eid, events, init, trees)
		else
			update_transform_field(e.transform, events, init)
			local trans = e.transform
			trans.world(ms:srtmat(trans))
			--TODO: mark parent to cache, if no other hirarchy node change, we can only call 'mark_cache' function here
			local peid = trans.parent
			if peid then
				assert(world[peid].hierarchy)
				add_hierarchy_tree_item(peid, nil, true, trees)
			end
		end
	end

	for msg in hierarchy_mb:each() do
		add_hierarchy_tree_item(msg[3], nil, true, trees)
	end

	for msg in ignore_parent_scale_mb:each() do
		add_hierarchy_tree_item(msg[3], nil, true, trees)
	end

	-- remove 'ignore_parent_scale' need update hierarchy tree
	for msg in ignore_parent_scale_delete_mb:each() do
		local eid = msg[3]
		if world[eid] then
			add_hierarchy_tree_item(eid, nil, true, trees)
		end
	end

	local transform = world:singleton "hierarchy_transform_result"
	if next(trees) then
		update_hierarchy_tree(trees, transform)
	end

	hierarchy_del_handle(transform)
end
