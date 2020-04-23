local ecs = ...

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local assetmgr = import_package "ant.asset"
local animodule = require "hierarchy.animation"

local bgfx      = require "bgfx"

local ozzmesh_skinning_transform = ecs.transform "ozzmesh_skinning"

local function find_layout(shortname, layouts)
	for _, l in ipairs(layouts) do
		if shortname == l:sub(1, 1) then
			return l
		end
	end
end

local function generate_layout(shortnames, layouts)
	local layout = {}
	for _, sn in ipairs(shortnames) do
		local l = find_layout(sn, layouts)
		if l then
			layout[#layout+1] = l
		end
	end

	if next(layout) then
		return table.concat(layout, '|')
	end
end

local function create_dynamic_buffer(layouts, num_vertices, ozzmesh)
	local dynamic_layout = generate_layout({'p', 'n', 'T'}, layouts)
	local dynamic_stride = declmgr.layout_stride(dynamic_layout)
	local dynamic_buffersize = num_vertices * dynamic_stride
	local dynamic_buffer = animodule.new_aligned_memory(dynamic_buffersize, 4)
	local dynamic_pointer = dynamic_buffer:pointer()
	ozzmesh:combine_buffer(dynamic_layout, dynamic_pointer)
	return {
		handle = bgfx.create_dynamic_vertex_buffer({"!", dynamic_pointer, 0, dynamic_buffersize}, declmgr.get(dynamic_layout).handle),
		updatedata = dynamic_buffer,
	}
end

local function create_static_buffer(layouts, num_vertices, ozzmesh)
	local static_layout = generate_layout({'c', 't'}, layouts)
	local static_stride = declmgr.layout_stride(static_layout)
	local static_buffersize = num_vertices * static_stride
	local static_buffer = animodule.new_aligned_memory(static_buffersize, 4)
	local static_pointer = static_buffer:pointer()
	ozzmesh:combine_buffer(static_layout, static_pointer)
	return {
		handle = bgfx.create_vertex_buffer({"!", static_pointer, 0, static_buffersize}, declmgr.get(static_layout).handle)
	}
end

local function gen_mesh_assetinfo(ozzmesh)
	local layouts = ozzmesh:layout()
	local num_vertices = ozzmesh:num_vertices()

	local primitive = {
		vb = {
			start = 0,
			num = num_vertices,
			handles = {
				create_static_buffer(layouts, num_vertices, ozzmesh),
				create_dynamic_buffer(layouts, num_vertices, ozzmesh),
			}
		}
	}

	local num_indices = ozzmesh:num_indices()
	
	if num_indices ~= 0 then
		local indices_buffer, stride = ozzmesh:index_buffer()
		primitive.ib = {
			start = 0,
			num = num_indices,
			handle = bgfx.create_index_buffer({indices_buffer, 0, num_indices * stride})
		}
	end

	local ibm_pointer, ibm_count = ozzmesh:inverse_bind_matrices()
	local joint_remapp_pointer, count = ozzmesh:joint_remap()
	return {
		default_scene = "sceneroot",
		scenes = {
			sceneroot = {
				meshnode = {
					inverse_bind_pose 	= animodule.new_bind_pose(ibm_count, ibm_pointer),
					joint_remap 		= animodule.new_joint_remap(joint_remapp_pointer, count),
					primitive
				}
			}
		}
	}
end

local ozzmesh_loader = ecs.transform "ozzmesh_loader"

function ozzmesh_loader.process(e)
	local meshfilename = tostring(e.mesh)
	local f, _ = meshfilename:match "([^:]+):"
	local stem, ext = f:match "[/\\]([%w_-]+)%.([%w_-]+)$"
	assert(ext == "ozz")
	local filename 	= "//res.mesh/" .. stem .. ".rendermesh"
	e.rendermesh	= assetmgr.load(filename, gen_mesh_assetinfo(e.mesh.handle))
end

local function patch_dynamic_buffer(ozzmesh, scene)
	local meshname = next(scene)

	local patch_scene = {
		[meshname] = {
			{
				vb = {handles = {}}
			}
		}
	}

	local new_scene = assetmgr.patch(scene, patch_scene)

	local layouts = ozzmesh:layout()
	local num_vertices = ozzmesh:num_vertices()

	local mn = new_scene[meshname]
	local g = mn[1]
	g.vb.handles[2] = create_dynamic_buffer(layouts, num_vertices, ozzmesh)
	return new_scene
end

function ozzmesh_skinning_transform.process(e)
	local meshres 	= e.mesh.handle
	local meshscene = e.rendermesh
	local scene = patch_dynamic_buffer(meshres, meshscene.scenes[meshscene.default_scene])
	meshscene.scenes[meshscene.default_scene] = scene

	local _, meshnode = next(scene)

	local group = meshnode[1]

	local skincomp = e.skinning
	skincomp.jobs = {
		{
			inverse_bind_pose = meshnode.inverse_bind_pose,
			joint_remap = meshnode.joint_remap,
			parts = {},
		}
	}

	local job = skincomp.jobs[1]
	local parts = job.parts
	
	local vb = group.vb

	for idx, handle in ipairs(vb.handles) do
		local updatedata = handle.updatedata
		-- dynamic buffer, need patch
		if updatedata then

			job.hwbuffer_handle = handle.handle
			job.updatedata 		= updatedata

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

				parts[#parts+1] = {
					layout_stride 	= layout_stride,
					num 			= part_num_vertices,
					inputdesc 		= input_desc,
					outputdesc 		= output_desc,
					influences_count= meshres:influences_count(ipart),
				}
			end

			job.buffersize = output_buffer_offset
		end
	end

end