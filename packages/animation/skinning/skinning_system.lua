local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local fs 		= require "filesystem"

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
local ozzmesh = ecs.component_alias("ozz_mesh", "resource") {depend = {"rendermesh", "animation"}}

local function gen_mesh_assetinfo(ozzmesh)
	local smhandle = assetmgr.get_resource(ozzmesh.ref_path).handle

	local num_vertices, num_indices = smhandle:num_vertices(), smhandle:num_indices()

	local vbhandles = {}
	local create_buffer_op = {dynamic=bgfx.create_dynamic_vertex_buffer, static=bgfx.create_vertex_buffer}

	for _, buffertype in ipairs {"dynamic", "static"} do
		local layout = smhandle:layout(buffertype)
		local buffer, size = smhandle:buffer(buffertype)
		vbhandles[#vbhandles+1] = create_buffer_op[buffertype]({"!", buffer, size}, declmgr.get(layout).handle)
	end

	local idxbuffer, indices_sizebyte = smhandle:index_buffer()
	return computil.assign_group_as_mesh {
		vb = {
			handles = vbhandles,
			start = 0,
			num = num_vertices,
		},
		ib = {
			handle = bgfx.create_index_buffer {idxbuffer, indices_sizebyte},
			start = 0,
			num = num_indices,
		}
	}
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
	local ske = e.skeleton
	local res = assetmgr.get_resource(self.ref_path)
	-- for support dynamic vertex buffer, we need duplicate this meshscene
	-- if we only support static vertex buffer, we will not need this code
	local function deep_copy(t)
		local tt = {}
		for k, v in pairs(t) do
			tt[k] = type(tt) == "table" and deep_copy(v) or v
		end
		return tt
	end

	local newmesh_scene = deep_copy(res.handle)

	for _, meshnode in ipairs(newmesh_scene) do
		for _, group in ipairs(meshnode) do
			local values = assert(group.vb.values)
			for idx, value in ipairs(values) do
				if value then
					assert(group.vb.handles[idx] == false)

					local data = value.data
					group.vb.handles[idx] = bgfx.create_dynamic_vertex_buffer(
						{"!", data, 1, #data}, value.decl.handle
					)
					value.datapointer = bgfx.memory_texture(data)
					value.updatedata = bgfx.memory_texture(#data)
				end
			end
		end
		local ibp = meshnode.inverse_bind_pose
		if ibp then
			meshnode.inverse_bind_pose_result = animodule.new_bind_pose(#ske, ibp)
		end
	end
	rm.reskey = assetmgr.register_resource(fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh"), newmesh_scene)

	return self
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

function skinning_sys:update()
	for _, eid in world:each "skinning_mesh" do
		local e = world[eid]

		local meshscene = assetmgr.get_resource(assert(e.rendermesh.reskey))
		local aniresult = e.animation.aniresult

		for _, meshnode in ipairs(meshscene) do
			for _, group in ipairs(meshnode) do
				local vb = group.vb
				local values = assert(vb.values)
				for idx, value in ipairs(values) do
					local updatedata = value.updatedata
					local datapointer = value.datapointer

					animodule.mesh_skinning(aniresult, meshnode.inverse_bind_pose_result,
						datapointer, updatedata, group.num, value.declname)
					
					local handle = vb.handles[idx]
					bgfx.update(handle, 0, {"!", updatedata, #updatedata})
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