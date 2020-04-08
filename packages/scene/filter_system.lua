local ecs = ...
local world = ecs.world

local render = import_package "ant.render"
local computil = render.components

local assetmgr = import_package "ant.asset"

local math3d = require "math3d"

ecs.component_alias("filter_tag", "string")

local pf = ecs.component "primitive_filter"
	.filter_tag "filter_tag" ("can_render")

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

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.require_singleton "hierarchy_transform_result"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.n = 0
	end
end

--[[	!NOTICE!
	the material component defined with 'multiple' property which mean:
	1. there is only one material, the 'material' component reference this material item;
	2. there are more than one material, the 'material' component itself keep the first material item
		other items will store in array, start from 1 to n -1;
	examples:
	...
	world:create_entity {
		...
		material = {
			ref_path=def_path1,
		}
	}
	...
	this entity's material component itself represent 'def_path1' material item, and NO any array item

	...
	world:create_entity {
		...
		material = {
			ref_path=def_path1,
			{ref_path=def_path2},
		}
	}
	entity's material component same as above, but it will stay a array, and array[1] is 'def_path2' material item

	About the 'prim.material' field
	prim.material field it come from glb data, it's a index start from [0, n-1] with n elements

	Here 'primidx' stand for primitive index in mesh, it's a lua index, start from [1, n] with n elements
]]
local function get_material(prim, primidx, materialcomp, material_refs)
	local materialidx
	if material_refs then
		local idx = material_refs[primidx] or material_refs[1]
		materialidx = idx - 1
	else
		materialidx = prim.material or primidx - 1
	end

	return materialcomp[materialidx] or materialcomp
end

local function is_visible(meshname, submesh_refs)
	if submesh_refs == nil then
		return true
	end

	if submesh_refs then
		local ref = submesh_refs[meshname]
		if ref then
			return ref.visible
		end
		return true
	end
end

local function get_material_refs(meshname, submesh_refs)
	if submesh_refs then
		local ref = submesh_refs[meshname]
		if ref then
			return ref.material_refs
		end
	end
end

local function add_result(eid, group, materialinfo, properties, worldmat, aabb, result)
	local idx = result.n + 1
	local r = result[idx]
	if r == nil then
		r = {
			mgroup 		= group,
			material 	= assert(materialinfo),
			properties 	= properties,
			worldmat 	= worldmat,
			aabb		= aabb,
			eid 		= eid,
		}
		result[idx] = r
	else
		r.mgroup 	= group
		r.material 	= assert(materialinfo)
		r.properties= properties
		r.worldmat 	= worldmat
		r.aabb		= aabb
		r.eid 		= eid
	end
	result.n = idx
	return r
end

-- make a material cache
local material_cache = setmetatable( {}, { __mode = "kv" } )

local function invisible() end

local function cache_material(rendermesh, materialcomp)
	local cache = {}
	local meshscene = assetmgr.get_resource(rendermesh.reskey)
	local scene = meshscene.scenes[meshscene.default_scene]
	local submesh_refs = rendermesh.submesh_refs
	local n = 0

	for meshname, meshnode in pairs(scene) do
		if is_visible(meshname, submesh_refs) then
			local material_refs = get_material_refs(meshname, submesh_refs)

			for groupidx, group in ipairs(meshnode) do
				local material = get_material(group, groupidx, materialcomp, material_refs)
				local transparency = material.fx.surface_type.transparency
				n = n + 1
				cache[n] = {
					group,	-- 1
					material,	-- 2
					material.properties,	-- 3
					transparency,	-- 4
					group.bounding and group.bounding.aabb or nil,	-- 5
					meshnode.transform,	-- 6
				}
			end
		end
	end

	if n == 0 then
		return invisible
	elseif n == 1 then
		cache = cache[1]
		return function(eid, etrans, filter)
			local group = cache[1]
			local material = cache[2]
			local properties = cache[3]
			local transparency = cache[4]
			local aabb = cache[5]
			local localtrans = cache[6]
			local resulttarget = assert(filter.result[transparency])
			local worldaabb, worldtrans = math3d.aabb_transform(etrans, aabb, localtrans)
			add_result(eid, group, material, properties, worldtrans, worldaabb, resulttarget)
		end
	else
		return function(eid, etrans, filter)
			local result = filter.result
			local aabb_transform = math3d.aabb_transform
			for i = 1,n do
				local item = cache[i]
				local group = item[1]
				local material = item[2]
				local properties = item[3]
				local transparency = item[4]
				local aabb = item[5]
				local localtrans = item[6]
				local resulttarget = assert(result[transparency])
				local worldaabb, worldtrans = aabb_transform(etrans, aabb, localtrans)
				add_result(eid, group, material, properties, worldtrans, worldaabb, resulttarget)
			end
		end
	end
end

local function update_entity_transform(hierarchy_cache, eid)
	local e = world[eid]
	if e.hierarchy or e.lock_target then
		return
	end

	local transform = e.transform

	local srt = transform.srt
	local peid = transform.parent
	local worldmat = transform.world

	if peid then
		local parentresult = hierarchy_cache[peid]
		if parentresult then
			local parentmat = parentresult.world
			local hie_result = parentresult.hierarchy
			local slotname = transform.slotname

			if hie_result and slotname then
				local hiemat = hie_result[slotname]
				worldmat.m = math3d.mul(parentmat, math3d.mul(hiemat, srt))
			else
				worldmat.m = math3d.mul(parentmat, srt)
			end
			return
		end
	end
	worldmat.m = srt
end

local function reset_hierarchy_transform_result(hierarchy_cache)
	for k in pairs(hierarchy_cache) do
		hierarchy_cache[k] = nil
	end
end

function primitive_filter_sys:update_transform()
	local hierarchy_cache = world:singleton "hierarchy_transform_result"
	for _, eid in world:each "transform" do
		--TODO: catch transform changed event, only update transform changed entity
		update_entity_transform(hierarchy_cache, eid)
	end

	reset_hierarchy_transform_result(hierarchy_cache)
end

local material_change = world:sub { "material_change" }

function primitive_filter_sys:filter_primitive()
	for msg in material_change:each() do
		local eid = msg[2]
		material_cache[eid] = nil
	end

	for _, prim_eid in world:each "primitive_filter" do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		reset_results(filter.result)
		local filtertag = filter.filter_tag

		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			local func = material_cache[eid]
			if func then
				func(eid, ce.transform.world, filter)
			else
				func = cache_material(ce.rendermesh, ce.material)
				material_cache[eid] = func
				func(eid, ce.transform.world, filter)
			end
		end
	end
end

