local ecs = ...
local world = ecs.world

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

function mesh_skinning_transform.process(e, eid)
	world:add_component(eid, "skinning", {})

	local skinning = e.skinning

	local jobs = {}
	skinning.jobs = jobs

	e.rendermesh = assetmgr.patch(e.rendermesh, {vb={handles={}}})
	local primgroup = e.rendermesh
	skinning.skin = primgroup.skin
	local poseresult = e.pose_result
	skinning.skinning_matrices = animodule.new_bind_pose(poseresult:count())

	for idx, h in ipairs(primgroup.vb.handles) do
		if h.handle == nil then
			local start_bytes = h.start
			local end_bytes = start_bytes + h.num - 1

			local updatedata = animodule.new_aligned_memory(h.num, 4)
			local vbhandle = bgfx.create_dynamic_vertex_buffer({"!", h.value, start_bytes, end_bytes},
			declmgr.get(h.declname).handle)

			primgroup.vb.handles[idx] = {
				handle = vbhandle,
				updatedata = updatedata,
			}

			local outptr = updatedata:pointer()

			local declname = h.declname

			local layout_stride = declmgr.get(declname).stride
			local layout_elems = {}
			for elem in declname:gmatch "%w+" do
				layout_elems[#layout_elems+1] = elem
			end

			jobs[#jobs+1] = {
				hwbuffer_handle = vbhandle,
				updatedata = updatedata,
				buffersize = h.num,
				parts = {
					{
						inputdesc = layout_desc({'p', 'n', 'T', 'w', 'i'}, layout_elems, layout_stride, h.value, start_bytes),
						outputdesc = layout_desc({'p', 'n', 'T'}, layout_elems, layout_stride, outptr),
						num = h.num / layout_stride,
						layout_stride = layout_stride,
						influences_count = 4,
					}
				}
			}
		end
	end
end