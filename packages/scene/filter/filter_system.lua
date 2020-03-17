local ecs = ...
local world = ecs.world

local render = import_package "ant.render"
local ru = render.util
local computil = render.components

local filterutil = require "filter.util"

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local math3d = require "math3d"

local filter_properties = ecs.system "filter_properties"
filter_properties.require_singleton "render_properties"
filter_properties.require_interface "ant.render|uniforms"

function filter_properties:load_render_properties()
	local render_properties = world:singleton "render_properties"
	filterutil.load_lighting_properties(world, render_properties)
	filterutil.load_shadow_properties(world, render_properties)
	filterutil.load_postprocess_properties(world, render_properties)
end

local primitive_filter_sys = ecs.system "primitive_filter_system"

primitive_filter_sys.require_system "filter_properties"
primitive_filter_sys.require_singleton "hierarchy_transform_result"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.cacheidx = 1
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

local function get_scene_scale_mat(meshscene)
	local scenescale = meshscene.scenescale
	if scenescale and scenescale ~= 1 then
		local scalemat = meshscene.scalemat
		if scalemat == nil then
			scalemat = math3d.matrix{s=scenescale}
			meshscene.scalemat = math3d.ref(scalemat)
		end
		return scalemat
	end
end

local function get_mesh_local_trans(meshnode, scalemat)
	local meshtrans = meshnode.transform
	if meshtrans then
		local localtrans = meshnode.localtrans
		if localtrans == nil then
			localtrans = scalemat and math3d.mul(scalemat, meshtrans) or meshtrans
			meshnode.localtrans = math3d.ref(localtrans)
		end

		return localtrans
	end
end

local function transform_bounding_aabb(entitytrans, localtrans, aabb)
	if aabb then
		local worldtrans = math3d.mul(entitytrans, localtrans)
		return math3d.aabb_transform(worldtrans, aabb)
	end
end

local function add_result(eid, group, materialinfo, properties, worldmat, aabb, result)
	local idx = result.cacheidx
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
		r.bounding	= aabb
		r.eid 		= eid
	end
	result.cacheidx = idx + 1
	return r
end

local function insert_primitive(eid, group, material, worldmat, bounding, filter)
	local refkey = material.ref_path
	local mi = assert(assetmgr.get_resource(refkey))
	local resulttarget = assert(filter.result[mi.fx.surface_type.transparency])
	add_result(eid, group, mi, material.properties, worldmat, bounding, resulttarget)
end

local function filter_element(eid, rendermesh, etrans, materialcomp, filter)
	local meshscene = assetmgr.get_resource(rendermesh.reskey)

	local sceneidx = computil.scene_index(rendermesh.lodidx, meshscene)
	local scalemat = get_scene_scale_mat(meshscene)

	local scenes = meshscene.scenes[sceneidx]
	local submesh_refs = rendermesh.submesh_refs
	for _, meshnode in ipairs(scenes) do
		local name = meshnode.meshname
		if is_visible(name, submesh_refs) then
			local localtrans = get_mesh_local_trans(meshnode, scalemat)
			local material_refs = get_material_refs(name, submesh_refs)

			for groupidx, group in ipairs(meshnode) do
				local material = get_material(group, groupidx, materialcomp, material_refs)
				--TODO: we will cache world transform and bounding transform
				local worldtrans = localtrans and math3d.mul(etrans, localtrans) or etrans
				local aabb = transform_bounding_aabb(etrans, localtrans, group.bounding and group.bounding.aabb or nil)
				insert_primitive(eid, group, material, worldtrans, aabb, filter)
			end
		end
	end
end

-- TODO: we should optimize this code, it's too inefficient!
local function is_entity_prepared(e)
	local rm = e.rendermesh
	if assetmgr.get_resource(rm.reskey) == nil then
		return false
	end

	for _, m in world:each_component(e.material) do
		if assetmgr.get_resource(m.ref_path) == nil then
			return false
		end

		local p = m.properties
		if p then
			local t = p.textures
			if t then
				for k, tex in pairs(t) do
					if assetmgr.get_resource(tex.ref_path) == nil then
						return false
					end
				end
			end
		end
	end
	
	return true
end

local function update_entity_transform(hierarchy_cache, eid)
	local e = world[eid]

	local transform = e.transform
	local worldmat = transform.srt
	if e.hierarchy == nil then
		local peid = transform.parent
		
		if peid then
			local parentresult = hierarchy_cache[peid]
			if parentresult then
				local parentmat = parentresult.world
				local hie_result = parentresult.hierarchy
				local slotname = transform.slotname

				-- TODO: why need calculate one more time here.
				-- when delete a hierarchy node, it's children will not know parent has gone
				-- no update for 'transform.world', here will always calculate one more time
				-- if we want cache this result, we need to find all the children when hierarchy
				-- node deleted, and update it's children at that moment, then we can save 
				-- this calculation.
				if hie_result and slotname then
					local hiemat = hie_result[slotname]
					worldmat.m = math3d.mul(parentmat, math3d.mul(hiemat, worldmat))
				else
					worldmat.m = math3d.mul(parentmat, worldmat)
				end
			end
		end
	end

	return worldmat
end

local function reset_hierarchy_transform_result(hierarchy_cache)
	for k in pairs(hierarchy_cache) do
		hierarchy_cache[k] = nil
	end
end

function primitive_filter_sys:filter_primitive()
	local hierarchy_cache = world:singleton "hierarchy_transform_result"
	for _, prim_eid in world:each "primitive_filter" do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		reset_results(filter.result)
		local filtertag = filter.filter_tag

		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			if is_entity_prepared(ce) then
				local worldmat = update_entity_transform(hierarchy_cache, eid)
				filter_element(eid, ce.rendermesh, worldmat, ce.material, filter)
			end
		end
	end

	reset_hierarchy_transform_result(hierarchy_cache)
end

