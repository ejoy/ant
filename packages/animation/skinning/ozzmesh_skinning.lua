local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local assetpkg  = import_package "ant.asset"
local assetmgr  = assetpkg.mgr

local fs        = require "filesystem"
local animodule = require "hierarchy.animation"

local bgfx      = require "bgfx"

local s = ecs.policy "ozz_skinning"
s.require_component "animation"
s.require_component "skeleton"
s.require_component "rendermesh"
s.require_component "skinning"
s.require_component "mesh"
s.require_component "pose_result"
s.require_transform "ozzmesh_skinning"
s.require_transform "ozzmesh_loader"
s.require_system "skinning_system"

local ozzmesh_policy = ecs.policy "ozzmesh"
ozzmesh_policy.require_component "rendermesh"
ozzmesh_policy.require_component "mesh"

ozzmesh_policy.require_transform "ozzmesh_loader"

local ozzmesh_skinning_transform = ecs.transform "ozzmesh_skinning"
ozzmesh_skinning_transform.input 	"mesh"
ozzmesh_skinning_transform.input 	"rendermesh"
ozzmesh_skinning_transform.output 	"skinning"

local function gen_mesh_assetinfo(ozzmesh)
	local meshhandle = assetmgr.get_resource(ozzmesh.ref_path).handle

	local layouts = meshhandle:layout()
	local num_vertices = meshhandle:num_vertices()

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

	local static_layout = generate_layout({'c', 't'}, layouts)
	local static_stride = declmgr.layout_stride(static_layout)
	local static_buffersize = num_vertices * static_stride
	local static_buffer = animodule.new_aligned_memory(static_buffersize, 4)
	local static_pointer = static_buffer:pointer()
	meshhandle:combine_buffer(static_layout, static_pointer)
	local static_vbhandle = {
		handle = bgfx.create_vertex_buffer({"!", static_pointer, 0, static_buffersize}, declmgr.get(static_layout).handle)
	}

	local dynamic_layout = generate_layout({'p', 'n', 'T'}, layouts)
	local dynamic_stride = declmgr.layout_stride(dynamic_layout)
	local dynamic_buffersize = num_vertices * dynamic_stride
	local dynamic_buffer = animodule.new_aligned_memory(dynamic_buffersize, 4)
	local dynamic_pointer = dynamic_buffer:pointer()
	meshhandle:combine_buffer(dynamic_layout, dynamic_pointer)
	local dynamic_vbhandle = {
		handle = bgfx.create_dynamic_vertex_buffer({"!", dynamic_pointer, 0, dynamic_buffersize}, declmgr.get(dynamic_layout).handle),
		updatedata = dynamic_buffer,
	}

	local primitive = {
		vb = {
			start = 0,
			num = num_vertices,
			handles = {
				static_vbhandle,
				dynamic_vbhandle,
			}
		}
	}

	local num_indices = meshhandle:num_indices()
	
	if num_indices ~= 0 then
		local indices_buffer, stride = meshhandle:index_buffer()
		primitive.ib = {
			start = 0,
			num = num_indices,
			handle = bgfx.create_index_buffer({indices_buffer, 0, num_indices * stride})
		}
	end

	local ibm_pointer, ibm_count = meshhandle:inverse_bind_matrices()
	local joint_remapp_pointer, count = meshhandle:joint_remap()
	return {
		sceneidx = 1,
		scenescale = 1.0,
		scenes = {
			--scene
			{
				--meshnode
				{
					inverse_bind_pose 	= animodule.new_bind_pose(ibm_count, ibm_pointer),
					joint_remap 		= animodule.new_joint_remap(joint_remapp_pointer, count),
					primitive
				}
			}
		}
	}
end

local ozzmesh_loader = ecs.transform "ozzmesh_loader"
ozzmesh_loader.input "mesh"
ozzmesh_loader.output "rendermesh"

function ozzmesh_loader.process(e)
	local rm 		= e.rendermesh
	local mesh 		= e.mesh
	local reskey 	= fs.path("//res.mesh/" .. mesh.ref_path:stem():string() .. ".mesh")
	rm.reskey 		= assetmgr.register_resource(reskey, gen_mesh_assetinfo(mesh))
end

function ozzmesh_skinning_transform.process(e)
	local meshscene = assetmgr.get_resource(e.rendermesh.reskey)
	local meshres 	= assetmgr.get_resource(e.mesh.ref_path).handle

	local scene = meshscene.scenes[meshscene.sceneidx]
	assert(#scene == 1 and #scene[1] == 1)
	local meshnode = scene[1]

	local primitive = meshnode[1]

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
	
	local vb = primitive.vb

	for _, handle in ipairs(vb.handles) do
		local updatedata = handle.updatedata
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