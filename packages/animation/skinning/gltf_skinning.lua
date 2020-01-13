local ecs = ...

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local assetpkg  = import_package "ant.asset"
local assetmgr  = assetpkg.mgr


local s = ecs.policy "skinning"
s.require_component "animation"
s.require_component "skeleton"
s.require_component "pose_result"
s.require_component "skinning"
s.require_transform "mesh_skinning"

s.require_component "rendermesh"
s.require_component "mesh"

s.require_transform "ant.render|mesh_loader"
s.require_transform "ant.animation|pose_result"
s.require_system "ant.animation|skinning_system"


local mesh_skinning_transform = ecs.transform "mesh_skinning"
mesh_skinning_transform.input "mesh"
mesh_skinning_transform.input "rendermesh"
mesh_skinning_transform.output "skinning"

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


function mesh_skinning_transform.process(e)
	local meshres = assetmgr.get_resource(e.mesh.ref_path)
	local meshscene = assetmgr.get_resource(e.rendermesh.reskey)

	local skinning = e.skinning

	local jobs = {}
	skinning.jobs = jobs

	for meshidx, meshnode in ipairs(meshscene.scenes[meshscene.sceneidx]) do
		local res_meshnode = meshres.scenes[meshres.sceneidx][meshidx]
		for groupidx, group in ipairs(meshnode) do
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

					jobs[#jobs+1] = {
						inverse_bind_pose = meshnode.inverse_bind_pose,
						joint_remap = meshnode.joint_remap,
						hwbuffer_handle = handle.handle,
						updatedata = updatedata,
						buffersize = layout_stride * vb.num,
						parts = {
							{
								inputdesc = layout_desc({'p', 'n', 'T', 'w', 'i'}, layout_elems, layout_stride, vbvalue, offset),
								outputdesc = layout_desc({'p', 'n', 'T'}, layout_elems, layout_stride, outptr),
								num = vb.num,
								layout_stride = layout_stride,
								influences_count = 4,
							}
						}
					}
				end
			end
		end
	end
end