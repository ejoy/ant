local ecs = ...
local world = ecs.world

ecs.import "ant.event"

local su 		= require "util"

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local animodule = require "hierarchy.animation"

ecs.component_alias("attach", "entityid")

ecs.singleton "hierarchy_transform_result"

local ur = ecs.singleton "hierarchy_update_result"
local function reset_hierarchy_update_result(rr)
	rr.removed_eids = {}
	rr.hierarchy_trees = {}
	rr.render_entities = {}
end

function ur.init()
	local rr = {}
	reset_hierarchy_update_result(rr)
	return rr
end

local scene_space = ecs.system "scene_space"
scene_space.dependby "primitive_filter_system"
scene_space.dependby "update_hirarchy_result_system"

scene_space.singleton "event"
scene_space.singleton "hierarchy_transform_result"
scene_space.singleton "hierarchy_update_result"

function scene_space:post_init()
	for eid in world:each_new("transform") do
		self.event:new(eid, "transform")
	end
end

local pseudoroot_eid = -1

local mark_mt = { 
	__index = function(marked, eid) 
		if eid == pseudoroot_eid then
			marked[pseudoroot_eid] = false
			return false
		end
		local e = world[eid]
		
		local pid = e.transform.parent
		if pid and marked[pid] then
			marked[eid] = pid
			return true
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

local function update_hirarchy_entity_world(trans)
	local srt = ms:srtmat(trans)
	local base = trans.base
	local worldmat = trans.world
	if base then
		srt = ms(trans.base, srt, "*P")	
	end

	local peid = trans.parent
	if peid then
		local parent = world[peid]
		local pt = parent.transform
		ms(worldmat, pt.world, srt, "*=")
	else
		ms(worldmat, srt, "=")
	end
	return worldmat
end

local function update_render_entity_world(transform, hierarchy_cache)
	local peid = transform.parent
	local localmat = ms:srtmat(transform)
	if peid then
		local parentresult = hierarchy_cache[peid]
		local parentmat = parentresult.world
		if parentmat then
			local hie_result = parentresult.hierarchy
			local slotname = transform.slotname
			if hie_result and slotname then
				local hiemat = ms:matrix(hie_result[slotname])
				localmat = ms(parentmat, hiemat, localmat, "**P")
			else
				localmat = ms(parentmat, localmat, "*P")
			end
		end
	end

	local w = transform.world
	ms(w, localmat, "=")
	return w
end

local function fetch_sort_tree_result(tree, componenttype)
	setmetatable(tree, mark_mt)
	mark_tree(tree, componenttype)
	return tree_sort(tree)
end

local function fetch_hirarchy_tree(tree)
	return fetch_sort_tree_result(tree, "hierarchy")
end

local function fetch_render_entity_tree(tree)
	return fetch_sort_tree_result(tree, "can_render")
end

local function mark_cache(eid, cache_result)
	local e = world[eid]
	local t = e.transform
	
	local cachemat = update_hirarchy_entity_world(t)
	assert(type(cachemat) == 'userdata')

	local hiecomp = assert(e.hierarchy)
	if hiecomp.ref_path then
		local hiehandle = assetmgr.get_hierarchy(hiecomp.ref_path).handle
		if t.hierarchy_result == nil then
			local bpresult = animodule.new_bind_pose_result(#hiehandle)
			hiehandle:bindpose_result(bpresult)
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

local function which_render_entities_changed(tree, renderentities)
	if next(tree) then
		local sort_result = fetch_render_entity_tree(tree)
		for i=1, #sort_result do
			local eid = sort_result[i]
			local e = assert(world[eid])
			if e.hierarchy then
				-- mean all the render child have been updated
				break
			end

			if renderentities[eid] == nil then
				renderentities[eid] = {nil, true}
			end
		end
	end
end

local function update_transform_field(trans, events, init)
	if init then
		assert(events == nil or (not next(events)))
		return true
	end

	local changed
	for k, v in pairs(events) do
		changed = true
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

local function update_render_entities_world(renderentities, hierarchy_cache)
	for eid, re in pairs(renderentities) do
		local events, init = re[1], re[2]
		local e = world[eid]
		local trans = e.transform
		if update_transform_field(trans, events, init) then
			update_render_entity_world(trans, hierarchy_cache)
		end
	end
end

function scene_space:delete()
	local hierarchy_cache = self.hierarchy_transform_result	
	local removed_eids = {}
	for eid, entity in world:each_removed "hierarchy" do
		hierarchy_cache[eid] = nil
		removed_eids[eid] = entity
	end

	if next(removed_eids) then
		local tree = {}
		for _, eid in world:each "transform" do
			local e = world[eid]
			local trans = e.transform
			
			-- parent have been remove but this child do not attach to new parent
			-- make it as new tree root
			if removed_eids[trans.parent] then
				trans.parent = nil
			end

			if e.hierarchy then
				tree[eid] = trans.parent or pseudoroot_eid
			end
		end

		self.hierarchy_update_result.removed_eids = removed_eids
		self.hierarchy_update_result.hierarchy_trees = tree
		world:update_func "update_hirarchy_tree" ()
	end
end

local function add_hierarchy_tree_item(eid, events, init, trees)
	local trans = world[eid].transform
	local oldparent = trans.parent
	if events then
		update_transform_field(trans, events, init)
	end

	local newparent = trans.parent
	if newparent ~= oldparent then
		local parentparent = world[newparent].transform.parent
		trees[newparent] = parentparent
	end
	
	trees[eid] = newparent or pseudoroot_eid
end

function scene_space:event_changed()
	local updateresult 		= self.hierarchy_update_result
	local trees 			= updateresult.hierarchy_trees
	local renderentities 	= updateresult.render_entities

	for eid in world:each_new "hierarchy" do
		add_hierarchy_tree_item(eid, nil, true, trees)
	end
	
	for eid, events, init in self.event:each "transform" do
		local e = world[eid]
		if e.hierarchy then
			add_hierarchy_tree_item(eid, events, init, trees)
		else
			renderentities[eid] = {events, init}
		end
	end

	world:update_func "update_hirarchy_tree" ()
end

local update_hirarchy_result_system = ecs.system "update_hirarchy_result_system"
update_hirarchy_result_system.singleton "hierarchy_update_result"
update_hirarchy_result_system.singleton "hierarchy_transform_result"

function update_hirarchy_result_system:update_hirarchy_tree()
	local rr = self.hierarchy_update_result
	local hiecache = self.hierarchy_transform_result

	update_hierarchy_tree(rr.hierarchy_trees, hiecache)
	which_render_entities_changed(rr.hierarchy_trees, rr.render_entities)
	update_render_entities_world(rr.render_entities, hiecache)

	reset_hierarchy_update_result(rr)
end