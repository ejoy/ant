local ecs = ...
local world = ecs.world

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

local prim_filter_sys = ecs.system "primitive_filter_system"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.n = 0
	end
end

local function get_material(prim, primidx, materialcomp)
	-- prim.material index from 0 and material is multi component start from 0
	local materialidx = prim.material or primidx - 1
	return materialcomp[materialidx] or materialcomp
end

local function add_result(eid, group, materialinfo, worldmat, aabb, result)
	local idx = result.n + 1
	local r = result[idx]
	if r == nil then
		r = {
			mgroup 		= group,
			material 	= assert(materialinfo),
			worldmat 	= worldmat,
			aabb		= aabb,
			eid 		= eid,
		}
		result[idx] = r
	else
		r.mgroup 	= group
		r.material 	= assert(materialinfo)
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
	local meshscene = rendermesh
	local scene = meshscene.scenes[meshscene.default_scene]
	local n = 0

	for _, meshnode in pairs(scene) do
		for groupidx, group in ipairs(meshnode) do
			local material = get_material(group, groupidx, materialcomp)
			local transparency = material.fx.surface_type.transparency

			n = n + 1
			cache[n] = {
				group,	-- 1
				material,	-- 2
				transparency,	-- 3
				group.bounding and group.bounding.aabb or nil,	-- 4
				meshnode.transform,	-- 5
			}
		end
	end

	if n == 0 then
		return invisible
	elseif n == 1 then
		cache = cache[1]
		return function(eid, etrans, filter)
			local group = cache[1]
			local material = cache[2]
			local transparency = cache[3]
			local aabb = cache[4]
			local localtrans = cache[5]
			local resulttarget = assert(filter.result[transparency])
			local worldaabb, worldtrans = math3d.aabb_transform(etrans, aabb, localtrans)
			add_result(eid, group, material, worldtrans, worldaabb, resulttarget)
		end
	else
		return function(eid, etrans, filter)
			local result = filter.result
			local aabb_transform = math3d.aabb_transform
			for i = 1,n do
				local item = cache[i]
				local group = item[1]
				local material = item[2]
				local transparency = item[3]
				local aabb = item[4]
				local localtrans = item[5]
				local resulttarget = assert(result[transparency])
				local worldaabb, worldtrans = aabb_transform(etrans, aabb, localtrans)
				add_result(eid, group, material, worldtrans, worldaabb, resulttarget)
			end
		end
	end
end

local material_change = world:sub { "material_change" }

function prim_filter_sys:filter_primitive()
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
				func(eid, ce.transform._world, filter)
			else
				func = cache_material(ce.rendermesh, ce.material)
				material_cache[eid] = func
				func(eid, ce.transform._world, filter)
			end
		end
	end
end

