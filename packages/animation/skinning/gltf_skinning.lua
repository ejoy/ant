local ecs = ...
local world = ecs.world
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

local function create_node(elem, offset, layout_stride, pointer)
	local elemsize = declmgr.elem_size(elem)
	return {
		pointer,
		offset,
		layout_stride,
	}, offset + elemsize
end

local function layout_desc(desc, declname, layout_stride, pointer, offset)
	offset = offset or 1
	for elem in declname:gmatch "%w+" do
		local name = declmgr.name_mapper[elem:sub(1, 1)]
		desc[name], offset = create_node(elem, offset, layout_stride, pointer)
	end
end

local function create_dynamic_buffer(buffer)
	local num_bytes = buffer.memory[3]
	return {
		memory = buffer.memory,
		handle = bgfx.create_dynamic_vertex_buffer(num_bytes, declmgr.get(buffer.declname).handle),
		declname = buffer.declname,
		updatedata = animodule.new_aligned_memory(num_bytes, 4),
	}
end

local function create_job(pnT_buffer, wi_buffer)
	local inputdesc = {}
	local stride = declmgr.layout_stride(pnT_buffer.declname)
	layout_desc(inputdesc, pnT_buffer.declname, stride, pnT_buffer.memory[1], pnT_buffer.memory[2])
	layout_desc(inputdesc, wi_buffer.declname, declmgr.layout_stride(wi_buffer.declname), wi_buffer.memory[1], wi_buffer.memory[2])

	local updatedata = pnT_buffer.updatedata
	local outputdesc = {}
	layout_desc(outputdesc, pnT_buffer.declname, stride, updatedata:pointer())
	local buffersize = pnT_buffer.memory[3]
	return {
		hwbuffer_handle = pnT_buffer.handle,
		updatedata = updatedata,
		buffersize = buffersize,
		parts = {
			{
				inputdesc = inputdesc,
				outputdesc = outputdesc,
				num = buffersize / stride,
				layout_stride = stride,
				influences_count = 4,
			}
		}
	}
end

local bgfx = require "bgfx"
local function set_skinning_transform(rc)
	local sm = rc.skinning_matrices
	bgfx.set_multi_transforms(sm:pointer(), sm:count())
end

local function build_rendermesh(rc, m)
	rc.ib = m.ib
	rc.vb = {
		start = m.vb.start,
		num = m.vb.num,
		handles = {
			m.vb[1].handle,
			m.vb[2] and m.vb[2].handle or nil,
		}
	}
end

local function build_transform(rc, skinning)
	rc.skinning_matrices = skinning.skinning_matrices
	rc.set_transform = set_skinning_transform
end

local function build_cpu_skinning_jobs(e, skinning)
	local m = e.mesh
	if #m.vb < 2 then
		error(("invalid mesh for cpu skinning, vb should include at least 2 vertex buffer, one for position/normal/tangent, another for weight/indices: %d"):format(#m.vb))
	end

	for l in m.vb[1].declname:gmatch "%w+" do
		local t = l:sub(1, 1)
		assert(t == 'p' or t == 'n' or t == 'T')
	end

	for l in m.vb[2].declname:gmatch "%w+" do
		local t = l:sub(1, 1)
		assert(t == 'w' or t == 'i')
	end

	local pnT_buffer = create_dynamic_buffer(m.vb[1])
	local jobs = {}
	skinning.jobs = jobs
	jobs[#jobs+1] = create_job(pnT_buffer, m.vb[2])

	local nm = {
		ib = m.ib,
		vb = {
			start=m.vb.start,
			num=m.vb.num,
			pnT_buffer,
			m.vb[3],
		}
	}
	e.mesh = nm

	build_rendermesh(e._rendercache, e.mesh)
end

function mesh_skinning_transform.process_entity(e)
	e.skinning = {}
	local skinning = e.skinning

	local poseresult = e.pose_result
	skinning.skinning_matrices = animodule.new_bind_pose(poseresult:count())

	skinning.skin = e.meshskin

	if e.skinning_type == "CPU" then
		build_cpu_skinning_jobs(e, skinning)
	else
		build_transform(e._rendercache, e.skinning)
	end
end