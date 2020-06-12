local ecs = ...

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local assetmgr = import_package "ant.asset"

local bgfx = require "bgfx"

local animodule = require "hierarchy.animation"

local st_trans = ecs.transform "skinning_type_transform"
function st_trans.process_prefab(e)
	e.skinning_type  = "GPU"
end

local mesh_skinning_transform = ecs.transform "mesh_skinning"

local function find_elem(namecode, layout_elems)
	for _, elem in ipairs(layout_elems) do
		if utf8.codepoint(elem:sub(1, 1)) == namecode then
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

local name_mapper = {
	[utf8.codepoint 'p'] = declmgr.name_mapper['p'],
	[utf8.codepoint 'n'] = declmgr.name_mapper['n'],
	[utf8.codepoint 'T'] = declmgr.name_mapper['T'],
	[utf8.codepoint 'i'] = declmgr.name_mapper['i'],
	[utf8.codepoint 'w'] = declmgr.name_mapper['w'],
	[utf8.codepoint 'c'] = declmgr.name_mapper['c'],
	[utf8.codepoint 't'] = declmgr.name_mapper['t'],
}

local function layout_desc(elem_prefixs, layout_elems, layout_stride, pointer, offset)
	local desc = {}
	offset = offset or 1

	for _, p in utf8.codes(elem_prefixs) do
		local elem = find_elem(p, layout_elems)
		if elem then
			local name = name_mapper[p]
			desc[name], offset = create_node(elem, offset, layout_stride, pointer)
		end
	end
	return desc
end

local function need_dynamic_buffer(declname)
	return declname:match "p....." ~= nil
end

local function build_cpu_skinning_jobs(e, skinning)
	local jobs = {}
	skinning.jobs = jobs

	e.rendermesh = assetmgr.patch(e.rendermesh, {vb={handles={}}})
	local primgroup = e.rendermesh

	for idx, vd in ipairs(primgroup.vb.values) do
		local declname = vd.declname
		if need_dynamic_buffer(declname) then
			local start_bytes = vd.memory[3] --TODO
			local num_bytes   = vd.memory[4] --TODO

			local updatedata = animodule.new_aligned_memory(num_bytes, 4)
			local vbhandle = bgfx.create_dynamic_vertex_buffer(vd.memory, declmgr.get(declname).handle)

			primgroup.vb.handles[idx] = vbhandle

			local outptr = updatedata:pointer()
			local layout_stride = declmgr.get(declname).stride
			local layout_elems = {}
			for elem in declname:gmatch "%w+" do
				layout_elems[#layout_elems+1] = elem
			end

			jobs[#jobs+1] = {
				hwbuffer_handle = vbhandle,
				updatedata = updatedata,
				buffersize = num_bytes,
				parts = {
					{
						inputdesc = layout_desc("pnTwi", layout_elems, layout_stride, vd.value, start_bytes),
						outputdesc = layout_desc("pnT", layout_elems, layout_stride, outptr),
						num = num_bytes / layout_stride,
						layout_stride = layout_stride,
						influences_count = 4,
					}
				}
			}
		end
	end
end

function mesh_skinning_transform.process_entity(e)
	e.skinning = {}
	local skinning = e.skinning

	local poseresult = e.pose_result
	skinning.skinning_matrices = animodule.new_bind_pose(poseresult:count())

	skinning.skin = e.meshskin

	if e.skinning_type == "CPU" then
		build_cpu_skinning_jobs(e, skinning)
	end
end