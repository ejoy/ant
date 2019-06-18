local ecs = ...
local world = ecs.world

ecs.import "ant.event"

local render = import_package "ant.render"
local mathbaselib = require "math3d.baselib"
local ru = render.util

local filterutil = require "filter.util"

local ms = import_package "ant.math" .stack
local math3d = require "math3d"

local filter_properties = ecs.system "filter_properties"
function filter_properties:update()
	for _, prim_eid in world:each("primitive_filter") do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		filterutil.load_lighting_properties(world, filter)
		if e.shadow == nil then
			filterutil.load_shadow_properties(world, filter)
		end

		filterutil.load_postprocess_properties(world, filter)
	end
end

local primitive_filter_sys = ecs.system "primitive_filter_system"
primitive_filter_sys.dependby "filter_properties"
primitive_filter_sys.singleton "hierarchy_transform_result"
primitive_filter_sys.singleton "event"

local function update_transform(transform, hierarchy_cache)
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

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.cacheidx = 1
	end
end

local function node_matrix(node)
	if node.matrix then
		return ms:matrix(node.matrix)
	end

	if node.scale or node.rotation or node.translation then
		return ms:srtmat(node.scale, node.rotation, node.translation)
	end
end

local function calc_node_transform(node, parentmat)
	local nodetrans = node_matrix(node)
	return nodetrans and ms(parentmat, nodetrans, "*P") or parentmat
end

local function get_material(prim, primidx, materialcontent, material_refs)
	if material_refs then
		local idx = material_refs[primidx] or 1
		return materialcontent[idx]
	end

	local materialidx = prim.material or 0
	return materialcontent[materialidx+1] or materialcontent[1]
end

local function traverse_scene(scene, eid, materialcontent, submesh_refs, worldmat, filter)
	local nodes, meshes = scene.nodes, scene.meshes
	local function is_visible(meshname)
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

	local function get_material_refs(meshname)
		if submesh_refs then
			local ref = assert(submesh_refs[meshname])
			return assert(ref.material_refs)
		end
	end

	local function traverse_scene_ex(scenenodes, parentmat)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx+1]

			local nodetrans = calc_node_transform(node, parentmat)
			if node.children then
				traverse_scene_ex(node.children, nodetrans)
			end

			local meshidx = node.mesh
			if meshidx then
				local mesh = meshes[meshidx+1]
				local meshname = mesh.name
				if is_visible(meshname) then
					local material_refs = get_material_refs(meshname)
					for idx, prim in ipairs(mesh.primitives) do
						ru.insert_primitive(eid, prim, scene, 
							get_material(prim, idx, materialcontent, material_refs),
							nodetrans, filter)
					end
				end
			end
		end
	end

	traverse_scene_ex(scene.scenes[scene.scene+1].nodes, worldmat)
end

function primitive_filter_sys:update()	

	for _, prim_eid in world:each("primitive_filter") do
		local e = world[prim_eid]
		local filter = e.primitive_filter
		reset_results(filter.result)
		local viewtag = filter.view_tag
		local filtertag = filter.filter_tag
		local boundings = {}
		for _, eid in world:each(filtertag) do
			local ce = world[eid]
			local vt = ce[viewtag]
			local ft = ce[filtertag]
			if vt and ft then
				local mesh = ce.mesh
				local assetinfo = mesh.assetinfo				
				local meshhandle = assetinfo.handle
				local worldmat = ce.transform.world
				local materialcontent = assert(ce.material.content)

				local scene = meshhandle
				if scene then
					if scene.scene then
						traverse_scene(scene, eid, materialcontent, mesh.submesh_refs, worldmat, filter)
					else
						ru.insert_primitive_old(eid, 
						meshhandle,
						assert(ce.material.content),
						worldmat,
						filter,
						ce.mesh.group_id)
					end
				end
			end
		end

		filter.scenebounding = mathbaselib.merge_boundings(ms, boundings)
	end
end

function primitive_filter_sys:post_init()	
	for eid in world:each_new("transform") do
		local e = world[eid]
		e.transform.world = math3d.ref "matrix"

		self.event:new(eid, "transform")
	end
end

function primitive_filter_sys:event_changed()
	local hierarchy_cache = self.hierarchy_transform_result
	for eid, events, init in self.event:each("transform") do
		local e = world[eid]
		local trans = e.transform

		if init then
			assert(not next(events))
			update_transform(e.transform, hierarchy_cache)
		else
			for k, v in pairs(events) do
				if k == 's' or k == 'r' or k == 't' then
					ms(trans[k], v, "=")
					update_transform(e.transform, hierarchy_cache)
				elseif k == 'parent' then
					trans.parent = v
					update_transform(e.transform, hierarchy_cache)
				elseif k == 'base' then
					ms(trans.base, v, "=")
					update_transform(e.transform, hierarchy_cache)
				end
			end
		end
	end
end

