local ecs = ...
local world = ecs.world

ecs.import "ant.event"

local render = import_package "ant.render"
local ru = render.util
local computil = render.components

local filterutil = require "filter.util"

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local filter_properties = ecs.system "filter_properties"
filter_properties.singleton "render_properties"

function filter_properties:update()
	local render_properties = self.render_properties
	filterutil.load_lighting_properties(world, render_properties)
	filterutil.load_shadow_properties(world, render_properties)
	filterutil.load_postprocess_properties(world, render_properties)
end

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.dependby 	"filter_properties"
primitive_filter_sys.depend 	"asyn_asset_loader"
primitive_filter_sys.singleton 	"hierarchy_transform_result"
primitive_filter_sys.singleton 	"event"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.cacheidx = 1
	end
end

local function get_material(prim, primidx, materialcomp, material_refs)
	local materialidx
	if material_refs then
		local idx = material_refs[primidx] or material_refs[1]
		materialidx = idx - 1
	else
		materialidx = prim.material or primidx - 1
	end

	return materialcomp[materialidx] or materialcomp[0]
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
	end
end

local function get_material_refs(meshname, submesh_refs)
	if submesh_refs then
		local ref = assert(submesh_refs[meshname])
		return assert(ref.material_refs)
	end
end

local function get_scale_mat(worldmat, scenescale)
	if scenescale and scenescale ~= 1 then
		return ms(worldmat, ms:srtmat(mu.scale_mat(scenescale)), "*P")
	end
	return worldmat
end

local function filter_element(eid, rendermesh, worldmat, materialcomp, filter)
	local meshscene = assetmgr.get_resource(assert(rendermesh.reskey))

	local sceneidx = computil.scene_index(rendermesh.lodidx, meshscene)

	local scenes = meshscene.scenes[sceneidx]
	local submesh_refs = rendermesh.submesh_refs
	for _, meshnode in ipairs(scenes) do
		local name = meshnode.meshname
		if is_visible(name, submesh_refs) then
			local trans = get_scale_mat(worldmat, meshscene.scenescale)
			if meshnode.transform then
				trans = ms(trans, meshnode.transform, "*P")
			end

			local material_refs = get_material_refs(name, submesh_refs)

			for groupidx, group in ipairs(meshnode) do
				local material = get_material(group, groupidx, materialcomp, material_refs)
				ru.insert_primitive(eid, group, material, trans, filter)
			end
		end
	end
end

local function is_entity_prepared(e)
	if e.asyn_load == nil then
		return true
	end

	return e.asyn_load == "loaded"
end

local function update_entity_transform(hierarchy_cache, eid)
	local e = world[eid]
	if e.hierarchy then
		return 
	end
	local transform = e.transform
	local peid = transform.parent
	
	if peid then
		local parentresult = hierarchy_cache[peid]
		if parentresult then
			local parentmat = parentresult.world
			if parentmat then
				local hie_result = parentresult.hierarchy
				local slotname = transform.slotname

				local localmat = ms:srtmat(transform)
				if hie_result and slotname then
					local hiemat = ms:matrix(hie_result[slotname])
					ms(transform.world, parentmat, hiemat, localmat, "**=")
				else
					ms(transform.world, parentmat, localmat, "*=")
				end
			end
		end
	end
end

local function reset_hierarchy_transform_result(hierarchy_cache)
	for k in pairs(hierarchy_cache) do
		hierarchy_cache[k] = nil
	end
end

function primitive_filter_sys:update()	
	local hierarchy_cache = self.hierarchy_transform_result
	for _, prim_eid in world:each "primitive_filter" do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		reset_results(filter.result)
		local viewtag = filter.view_tag
		local filtertag = filter.filter_tag

		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			local vt = ce[viewtag]
			local ft = ce[filtertag]
			if vt and ft then
				if is_entity_prepared(ce) then
					update_entity_transform(hierarchy_cache, eid)
					filter_element(eid, ce.rendermesh, ce.transform.world, ce.material, filter)
				end
			end
		end
	end

	reset_hierarchy_transform_result(hierarchy_cache)
end

