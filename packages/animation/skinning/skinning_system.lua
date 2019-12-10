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

local ozzmesh = ecs.component_alias("ozz_mesh", "resource") {depend = {"rendermesh", "animation"}}

local function gen_mesh_assetinfo(ozzmesh)
	local meshhandle = assetmgr.get_resource(ozzmesh.ref_path).handle

	local meshscene = {}

	local numpart = meshhandle:num_part()
	for partidx=1, numpart do
		local meshnode = {}
		local numvertices = meshhandle:num_vertices()
	end
end

function ozzmesh:postinit(e)
	local rm = e.rendermesh

	local reskey = fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh")
	rm.reskey = assetmgr.register_resource(reskey, gen_mesh_assetinfo(self))
end


local skinningmesh = ecs.component_alias("skinning_mesh", "resource") {depend = {"rendermesh", "animation", "skeleton"}}
.ref_path "string"

function skinningmesh:postinit(e)
	local rm = e.rendermesh
	local ske = assetmgr.get_resource(e.skeleton.ref_path).handle
	local res = assetmgr.get_resource(self.ref_path)
	-- for support dynamic vertex buffer, we need duplicate this meshscene
	-- if we only support static vertex buffer, we will not need this code
	local function deep_copy(t)
		local tt = {}
		for k, v in pairs(t) do
			tt[k] = type(v) == "table" and deep_copy(v) or v
		end
		return tt
	end

	local newmesh_res = deep_copy(res)

	local newmeshscene = newmesh_res.scenes[newmesh_res.sceneidx]
	for _, meshnode in ipairs(newmeshscene) do
		for _, group in ipairs(meshnode) do
			local values = assert(group.vb.values)
			for idx, value in ipairs(values) do
				if value then
					assert(group.vb.handles[idx] == false)
					local declname = value.declname
					local data = value.data
					group.vb.handles[idx] = bgfx.create_dynamic_vertex_buffer(
						{"!", data, 1, #data}, declmgr.get(declname).handle
					)
					value.datapointer = bgfx.memory_texture(data)
					value.updatedata = bgfx.memory_texture(#data)
				end
			end
		end
		local ibp = meshnode.inverse_bind_poses
		if ibp then
			local bpresult = animodule.new_bind_pose(#ske)
			local numjoints = #ske
			local ibp_joints = ibp.joints
			local ibp_value = ibp.value
			local function get_ibp_matrix_value(idx)
				local start = (idx-1) * 64+1
				local v = string.unpack("<c64", ibp_value, start)
				return v
			end
			local set_joints = {}
			for i=1, #ibp_joints do
				local jointidx = ibp_joints[i]+1
				bpresult:joint(jointidx, get_ibp_matrix_value(i))
				set_joints[jointidx] = true
			end

			local mat_identity = ms(mc.mat_identity, "m")
			for jointidx=1, numjoints do
				if not set_joints[jointidx] then
					bpresult:joint(jointidx, mat_identity)
				end
			end
			meshnode.inverse_bind_pose_result = bpresult
		end
	end
	rm.reskey = assetmgr.register_resource(fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh"), newmesh_res)

	return self
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

local function layout_desc(elem_prefixs, layout_elems, layout_stride, pointer)
	local desc = {}
	local offset = 0

	for _, elem_prefix in ipairs(elem_prefixs) do
		local elem = find_elem(elem_prefix, layout_elems)
		desc[#desc+1], offset = create_node(elem, offset, layout_stride, pointer)
	end
	return desc
end

function skinning_sys:update()
	for _, eid in world:each "skinning_mesh" do
		local e = world[eid]

		local meshscene = assetmgr.get_resource(assert(e.rendermesh.reskey))
		local aniresult = e.animation.aniresult

		for _, meshnode in ipairs(meshscene.scenes[meshscene.sceneidx]) do
			for _, group in ipairs(meshnode) do
				local vb = group.vb
				local values = assert(vb.values)
				for idx, value in ipairs(values) do
					if value then
						local updatedata = value.updatedata
						local datapointer = value.datapointer
						local declname = value.declname
						local layout_stride = declmgr.get(declname).stride
						local layout_elems = {}
						for elem in declname:gmatch "%w+" do
							layout_elems[#layout_elems+1] = elem
						end

						animodule.mesh_skinning(aniresult, meshnode.inverse_bind_pose_result,
							layout_desc({'p', 'n', 'T', 'w', 'i'}, layout_elems, layout_stride, datapointer),
							layout_desc({'p', 'n', 'T'}, layout_elems, layout_stride, updatedata), vb.num)

						local handle = vb.handles[idx]
						bgfx.update(handle, 0, {"!", updatedata, layout_stride * vb.num})
					end
				end
			end
		end

		-- local sm 		= assetmgr.get_resource(e.skinning_mesh.ref_path).handle
		-- local aniresult = e.animation.aniresult
		
		-- -- update data include : position, normal, tangent
		-- animodule.skinning(sm, aniresult)

		-- -- update mesh dynamic buffer
		-- local group = meshscene.scenes[1][1][1]
		-- local buffer, size = sm:buffer("dynamic")
		-- bgfx.update(group.vb.handles[1], 0, {"!", buffer, size})
	end
end