local ecs = ...
local world = ecs.world

ecs.import "ant.event"

local su = require "util"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local math3d = require "math3d"

local animodule = require "hierarchy.animation"

local hie_util = import_package "ant.scene".hierarchy

ecs.tag "hierarchy_tag"

ecs.component "hierarchy_transform"
	.s "vector"
	.r "vector"
	.t "vector"
	['opt'].parent "parent"
	['opt'].hierarchy "hierarchy"

ecs.component_alias("attach", "entityid")

ecs.singleton "hierarchy_transform_result"

local scene_space = ecs.system "scene_space"
scene_space.dependby "primitive_filter_system"
scene_space.singleton "event"
scene_space.singleton "hierarchy_transform_result"

local pseudoroot_eid = -1

local function find_children(marked, eid, componenttype)
	if eid == pseudoroot_eid then
		marked[pseudoroot_eid] = false
		return false
	end
	local e = world[eid]
	local pid = e[componenttype].parent
	if pid and marked[pid] then
		marked[eid] = pid
		return true
	end
	marked[eid] = false
	return false
end

local mark_mt = { __index = function(marked, eid) return find_children(marked, eid, "hierarchy_transform") end }

local render_mark_mt = {__index = function(marked, eid) return find_children(marked, eid, "transform") end}

local function mark_tree(tree, componenttype)
	for _, eid in world:each(componenttype) do
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
		local pt = parent.hierarchy_transform
		ms(worldmat, pt.world, srt, "*=")
	else
		ms(worldmat, srt, "=")
	end
	return worldmat
end

local function fetch_sort_tree_result(tree, mark_mt, componenttype)	
	setmetatable(tree, mark_mt)
	mark_tree(tree, componenttype)	
	return tree_sort(tree)
end

local function mark_cache(eid, cache_result)
	local e = world[eid]
	local t = e.hierarchy_transform
	local cachemat = update_world(t)
	assert(type(cachemat) == 'userdata')

	local hie = t.hierarchy
	if hie then
		local hiehandle = hie.assetinfo.handle
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
		local sort_result = fetch_sort_tree_result(tree, mark_mt, "hierarchy_transform")
		for i = #sort_result, 1, -1 do
			local eid = sort_result[i]
			mark_cache(eid, cache_result)
		end
	end
end

local function notify_render_child_changed(tree, tell)
	if next(tree) then
		local sort_result = fetch_sort_tree_result(tree, render_mark_mt, "transform")
		for i = 1, #sort_result do
			local eid = sort_result[i]
			local e = world[eid]
			if e.hierarchy_transform then
				-- mean all the render child have been updatedupdated
				break
			end

			tell(e.transform)
		end
	end
end

function scene_space:post_init()	
	for eid in world:each_new("hierarchy_transform") do
		local e = world[eid]
		local trans = e.hierarchy_transform		
		trans.world = math3d.ref "matrix"
		self.event:new(eid, "hierarchy_transform")
	end
end

function scene_space:delete()
	local hierarchy_cache = self.hierarchy_transform_result	
	local removed_eids = {}
	for eid in world:each_removed "hierarchy_transform" do		
		hierarchy_cache[eid] = nil
		removed_eids[eid] = true
	end

	if next(removed_eids) then
		local tree = {}
		for eid in pairs(hierarchy_cache) do
			local e = world[eid]
			local trans = e.hierarchy_transform
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
			for _, eid in world:each "transform" do
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

function scene_space:event_changed()	
	local trees = {}	
	for eid, events in self.event:each("hierarchy_transform") do
		local e = world[eid]
		local trans = e.hierarchy_transform
		local oldparent = trans.parent
		su.handle_transform(events, trans)

		local newparent = trans.parent
		if newparent ~= oldparent then
			local parentparent = world[newparent].hierarchy_transform.parent
			trees[newparent] = parentparent
		end
		
		trees[eid] = newparent or pseudoroot_eid
	end

	update_scene_tree(trees, self.hierarchy_transform_result)
	
	notify_render_child_changed(trees, function (trans) 
		trans.watcher._marked_init = true 
	end)

end