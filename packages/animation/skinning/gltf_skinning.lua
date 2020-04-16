local ecs = ...

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local assetmgr = import_package "ant.asset"

local bgfx = require "bgfx"

local animodule = require "hierarchy.animation"

local mesh_skinning_transform = ecs.transform "mesh_skinning"

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
		if elem then
			local name = declmgr.name_mapper[elem_prefix]
			desc[name], offset = create_node(elem, offset, layout_stride, pointer)
		end
	end
	return desc
end

local function patch_dynamic_buffer(meshres, meshscene)
	local patch_meshscene = {}
	local jobs = {}
	for scenename, scene in pairs(meshres.scenes) do
		local patch_scene = {}
		patch_meshscene[scenename] = patch_scene
		for meshname, meshnode in pairs(scene) do
			local patch_meshnode = {}
			patch_scene[meshname] = patch_meshnode
			for groupidx, group in ipairs(meshnode) do
				local vb = group.vb
				local patch_group = {vb={handles={}}}
				patch_meshnode[groupidx] = patch_group
				for idx, handle in ipairs(vb.values) do
					local value = vb.values[idx]
					if handle.updatedata then
						jobs[#jobs+1] = {
							load = function (patch_res)
								local s = patch_res.scenes[scenename]
								local mn = s[meshnode]
								local g = mn[groupidx]

								local start_bytes = value.start
								local end_bytes = start_bytes + value.num - 1

								g.vb.handles[idx] = {
									handle = bgfx.create_dynamic_vertex_buffer({"!", value.value, start_bytes, end_bytes},
														declmgr.get(value.declname).handle),
									updatedata = animodule.new_aligned_memory(value.num, 4),
								}
							end,
						}
					end
				end
			end
		end
	end

	local new_meshscene = assetmgr.patch(meshscene, patch_meshscene)
	for _, j in pairs(jobs) do
		j(new_meshscene)
	end

	return new_meshscene
end

function mesh_skinning_transform.process(e)
	local meshres = e.mesh

	local skinning = e.skinning

	local jobs = {}
	skinning.jobs = jobs

	e.rendermesh = patch_dynamic_buffer(meshres, e.rendermesh)

	for scenename, scene in pairs(e.rendermesh.scenes) do
		local res_scene = meshres.scenes[scenename]
		for meshname, meshnode in pairs(scene) do
			local res_meshnode = res_scene[meshname]
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
end