local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local mathpkg   = import_package "ant.math"
local ms		= mathpkg.stack
local mc 		= mathpkg.constant

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local fs 		= require "filesystem"

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

-- local ozzmesh = ecs.component_alias("ozz_mesh", "resource") {depend = {"rendermesh", "animation"}}

-- local function gen_mesh_assetinfo(ozzmesh)
-- 	local meshhandle = assetmgr.get_resource(ozzmesh.ref_path).handle

-- 	local layouts = meshhandle:layout()
-- 	local num_vertices = meshhandle:num_vertices()

-- 	local function find_layout(shortname, layouts)
-- 		for _, l in ipairs(layouts) do
-- 			if shortname == l:sub(1, 1) then
-- 				return l
-- 			end
-- 		end
-- 	end

-- 	local function generate_layout(shortnames, layouts)
-- 		local layout = {}
-- 		for _, sn in ipairs(shortnames) do
-- 			local l = find_layout(sn, layouts)
-- 			if l then
-- 				layout[#layout+1] = l
-- 			end
-- 		end

-- 		if next(layout) then
-- 			return table.concat(layout, '|')
-- 		end
-- 	end

-- 	local static_layout = generate_layout({'c', 't'}, layouts)
-- 	local static_stride = declmgr.layout_stride(static_layout)
-- 	local static_buffer = bgfx.memory_texture(num_vertices * static_stride)
-- 	meshhandle:combine_buffer(static_layout, static_buffer)
-- 	local static_vbhandle = {
-- 		handle = bgfx.create_vertex_buffer(static_buffer, declmgr.get(static_layout).handle)
-- 	}

-- 	local dynamic_layout = generate_layout({'p', 'n', 'T'}, layouts)
-- 	local dynamic_stride = declmgr.layout_stride(dynamic_layout)
-- 	local dynamic_vbhandle = {
-- 		handle = bgfx.create_dynamic_vertex_buffer(num_vertices * dynamic_stride, declmgr.get(dynamic_layout).handle),
-- 		updatedata = animodule.new_aligned_memory(num_vertices * dynamic_stride, 4)
-- 	}

-- 	local primitive = {
-- 		vb = {
-- 			start = 0,
-- 			num = num_vertices,
-- 			handles = {
-- 				static_vbhandle,
-- 				dynamic_vbhandle,
-- 			}
-- 		}
-- 	}

-- 	local num_indices = meshhandle:num_indices()
	
-- 	if num_indices ~= 0 then
-- 		local indices_buffer, stride = meshhandle:index_buffer()
-- 		primitive.ib = {
-- 			start = 0,
-- 			num = num_indices,
-- 			handle = bgfx.create_index_buffer({indices_buffer, num_indices * stride})
-- 		}
-- 	end

-- 	local ibm_pointer, ibm_count = meshhandle:inverse_bind_matrices()
-- 	local joint_remapp_pointer, count = meshhandle:joint_remap()
-- 	return {
-- 		sceneidx = 1,
-- 		scenescale = 1.0,
-- 		scenes = {
-- 			--scene
-- 			{
-- 				--meshnode
-- 				{
-- 					inverse_bind_pose 	= animodule.new_bind_pose(ibm_count, ibm_pointer),
-- 					joint_remap 		= animodule.new_joint_remap(joint_remapp_pointer, count),
-- 					primitive
-- 				}
-- 			}
-- 		}
-- 	}
-- end

-- function ozzmesh:postinit(e)
-- 	local rm = e.rendermesh

-- 	local reskey = fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh")
-- 	local skehandle = assetmgr.get_resource(e.skeleton.ref_path).handle
-- 	rm.reskey = assetmgr.register_resource(reskey, gen_mesh_assetinfo(self, skehandle))
-- end


-- local skinningmesh = ecs.component_alias("skinning_mesh", "resource") {depend = {"rendermesh", "animation", "skeleton"}}
-- .ref_path "respath"

-- function skinningmesh:postinit(e)
-- 	local rm = e.rendermesh
-- 	local res = assetmgr.get_resource(self.ref_path)
-- 	local meshscene = computil.create_mesh_buffers(res)

-- 	rm.reskey = assetmgr.register_resource(fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh"), meshscene)

-- 	return self
-- end

ecs.component_alias("skinning_mesh", "resource") {depend = {"rendermesh", "animation"}}

local s = ecs.policy "skinning"
s.require_component "animation"
s.require_component "skeleton"
s.require_component "rendermesh"
s.require_component "skinning_mesh"
s.require_transform "skinning"

local m = ecs.transform "skinning"
m.input "rendermesh"
m.input "animation"
m.output "skinning_mesh"

function m.process(e)
	local rm = e.rendermesh
	local reskey = fs.path("//meshres/" .. e.skinning_mesh.ref_path:stem():string() .. ".mesh")
	rm.reskey = assetmgr.register_resource(reskey, gen_mesh_assetinfo(e.skinning_mesh))
end


-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

local function find_elem(name, layout_elems)
	assert(#name == 1)
	for _, elem in ipairs(layout_elems) do
		if elem:sub(1, 1) == name then
			return elem
		end
	end
end

local function create_node(elem, offset, layout_stride, pointer)
	local elemsize = declmgr.elem_size(elem)
	return {
		pointer,
		offset,
		layout_stride,
	}, offset + elemsize
end

local function layout_desc(elem_prefixs, layout_elems, layout_stride, pointer, offset)
	local desc = {}
	offset = offset or 1

	for _, elem_prefix in ipairs(elem_prefixs) do
		local elem = find_elem(elem_prefix, layout_elems)
		local name = declmgr.name_mapper[elem_prefix]
		desc[name], offset = create_node(elem, offset, layout_stride, pointer)
	end
	return desc
end

local function build_skinning_matrices(meshnode, aniresult)
	local skinning_matrices = meshnode.skinning_matrices
	if skinning_matrices == nil then
		skinning_matrices = animodule.new_bind_pose(aniresult:count())
		meshnode.skinning_matrices = skinning_matrices
	end

	animodule.build_skinning_matrices(skinning_matrices, aniresult, meshnode.inverse_bind_pose, meshnode.joint_remap)
	return skinning_matrices
end

function skinning_sys:update()
	for _, eid in world:each "skinning_mesh" do
		local e = world[eid]

		local meshscene = assetmgr.get_resource(assert(e.rendermesh.reskey))
		local aniresult = e.animation.aniresult
		local meshres = assetmgr.get_resource(e.skinning_mesh.ref_path)

		for meshidx, meshnode in ipairs(meshscene.scenes[meshscene.sceneidx]) do
			local res_meshnode = meshres.scenes[meshscene.sceneidx][meshidx]
			for groupidx, group in ipairs(meshnode) do

				local skinning_matrices = build_skinning_matrices(meshnode, aniresult)
				local res_group = res_meshnode[groupidx]

				local vb = group.vb
				local res_vb = res_group.vb
				for idx, handle in ipairs(vb.handles) do
					local updatedata = handle.updatedata
					if updatedata then
						local outptr = updatedata:pointer()
						local res_value = res_vb.values[idx]
						local vbvalue = res_value.value
						local offset = res_value.start
						local declname = res_value.declname
						local layout_stride = declmgr.get(declname).stride
						local layout_elems = {}
						for elem in declname:gmatch "%w+" do
							layout_elems[#layout_elems+1] = elem
						end

						animodule.mesh_skinning(aniresult, skinning_matrices,
							layout_desc({'p', 'n', 'T', 'w', 'i'}, layout_elems, layout_stride, vbvalue, offset),
							layout_desc({'p', 'n', 'T'}, layout_elems, layout_stride, outptr), vb.num)

						bgfx.update(handle.handle, 0, {"!", outptr, layout_stride * vb.num})
					end
				end
			end
		end
	end

	for _, eid in world:each "ozz_mesh" do
		local e = world[eid]
		local meshres = assetmgr.get_resource(e.ozz_mesh.ref_path).handle
		local meshscene = assetmgr.get_resource(e.rendermesh.reskey)

		local aniresult = e.animation.aniresult

		local meshscene = meshscene.scenes[meshscene.sceneidx]
		assert(#meshscene == 1 and #meshscene[1] == 1)
		local meshnode = meshscene[1]

		local primitive = meshscene[1][1]
		local skinning_matrices = build_skinning_matrices(meshnode, aniresult)

		local vb = primitive.vb

		for _, handle in ipairs(vb.handles) do
			local updatedata = handle.updatedata
			if updatedata then
				local num_part = meshres:num_part()
				local outptr = updatedata:pointer()

				local output_buffer_offset = 0
				for ipart=1, num_part do
					local part_num_vertices = meshres:num_vertices(ipart)
					local input_desc, output_desc = {}, {}

					for _, n in ipairs {"p", "n", "T", "w", "i"} do
						local name = declmgr.name_mapper[n]
						input_desc[name] = meshres:vertex_buffer(ipart, name)
					end

					local offset = 0
					for _, n in ipairs{"p", "n", "T"} do
						local name = declmgr.name_mapper[n]
						local input = input_desc[name]
						output_desc[name] = {
							outptr,
							output_buffer_offset + offset + 1,
							nil,
						}
						offset = offset + input[3]
					end

					local layout_stride = offset
					for _, output in pairs(output_desc) do
						output[3] = layout_stride
					end

					output_buffer_offset = output_buffer_offset + layout_stride * part_num_vertices

					animodule.mesh_skinning(aniresult, skinning_matrices,
						input_desc, output_desc,
						part_num_vertices, meshres:influences_count(ipart)
					)
				end

				bgfx.update(handle.handle, 0, {'!', outptr, output_buffer_offset})
			end
		end
	end
end