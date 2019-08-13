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

local scene_space = ecs.system "scene_space"
scene_space.dependby "primitive_filter_system"
scene_space.singleton "event"
scene_space.singleton "hierarchy_transform_result"

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

local function update_world(trans)
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
	
	local cachemat = update_world(t)
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

local function update_scene_tree(tree, cache_result)
	if next(tree) then
		local sort_result = fetch_hirarchy_tree(tree)
		for i = #sort_result, 1, -1 do
			local eid = sort_result[i]
			mark_cache(eid, cache_result)
		end
	end
end

local function notify_render_child_changed(tree, tell)
	if next(tree) then
		local sort_result = fetch_render_entity_tree(tree)
		for i = 1, #sort_result do
			local eid = sort_result[i]
			local e = world[eid]
			if e.hierarchy then
				-- mean all the render child have been updated
				break
			end

			tell(e.transform)
		end
	end
end

function scene_space:delete()
	local hierarchy_cache = self.hierarchy_transform_result	
	local removed_eids = {}
	for eid, entity in world:each_removed "transform" do
		if entity.hierarchy then
			hierarchy_cache[eid] = nil
			removed_eids[eid] = entity
		end
	end

	if next(removed_eids) then
		local tree = {}
		for eid in pairs(hierarchy_cache) do
			local e = world[eid]
			local trans = e.transform
			local peid = trans.parent
			-- parent have been remove but this child do not attach to new parent
			-- make it as new tree root
			if removed_eids[peid] then
				trans.parent = nil
				update_world(trans)
			else
				tree[eid] = peid
			end
		end
		update_scene_tree(tree, hierarchy_cache)
		local function update_render_child()
			local cache = {}
			for _, eid in world:each "hierarchy" do
				local parent = world[eid].transform.parent
				if parent then 
					if cache[parent] == nil then
						cache[parent] = {}
					end 
					table.insert(cache[parent], eid)
				end
			end

			for remove_eid in pairs(removed_eids) do 
				local children = cache[remove_eid] 
				if children then
					for _, ceid in ipairs(children) do 
						local e = world[ceid]
						e.transform.parent = nil	-- could not use watcher.parent, because nil will not add notification to watcher
						e.transform.watcher._marked_init = true
					end
				end
			end
		end

		update_render_child()
	end
end

local function update_render_entity_transform(transform, hierarchy_cache)
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

function scene_space:event_changed()	
	local trees = {}
	local renderentities = {}
	for eid, events, init in self.event:each "transform" do
		local e = world[eid]

		if e.hierarchy then
			local trans = e.transform
			local oldparent = trans.parent
			su.handle_transform(events, trans)

			local newparent = trans.parent
			if newparent ~= oldparent then
				local parentparent = world[newparent].transform.parent
				trees[newparent] = parentparent
			end
			
			trees[eid] = newparent or pseudoroot_eid
		else
			renderentities[eid] = {events, init}
		end
	end

	update_scene_tree(trees, self.hierarchy_transform_result)
	
	notify_render_child_changed(trees, function (trans) 
		trans.watcher._marked_init = true 
	end)

	local hierarchy_cache = self.hierarchy_transform_result
	for eid, re in pairs(renderentities) do
		local events, init = re[1], re[2]
		local e = world[eid]
		local trans = e.transform

		if init then
			assert(not next(events))
			update_render_entity_transform(e.transform, hierarchy_cache)
		else
			for k, v in pairs(events) do
				if k == 's' or k == 'r' or k == 't' then
					ms(trans[k], v, "=")
					update_render_entity_transform(e.transform, hierarchy_cache)
				elseif k == 'parent' then
					trans.parent = v
					update_render_entity_transform(e.transform, hierarchy_cache)
				elseif k == 'base' then
					ms(trans.base, v, "=")
					update_render_entity_transform(e.transform, hierarchy_cache)
				end
			end
		end
	end
end