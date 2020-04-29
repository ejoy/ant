local math3d = require "math3d"
local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"
local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local function clone_bounding(b)
    if b then
        return {
            aabb = math3d.ref(b.aabb)
        }
    end
end

local function create_mesh_buffers(meshres)
	local meshscene = {
		scene = meshres.scene,
        scenelods = meshres.scenelods,
        scenescale = meshres.scenescale,
	}
	local new_scenes = {}
	for scenename, scene in pairs(meshres.scenes) do
		local new_scene = {}
		for meshname, meshnode in pairs(scene) do
			local new_meshnode = {
				bounding = meshnode.bounding,
				transform = meshnode.transform,
			}
			for _, group in ipairs(meshnode) do
				local vb = group.vb
				local handles = {}
				for _, value in ipairs(vb.values) do
					local create_vb = value.type == "dynamic" and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
					local start_bytes = value.start
					local end_bytes = start_bytes + value.num - 1

					handles[#handles+1] = {
						handle = create_vb({"!", value.value, start_bytes, end_bytes},
											declmgr.get(value.declname).handle),
						updatedata = value.type == "dynamic" and animodule.new_aligned_memory(value.num, 4) or nil,
					}
				end
				local new_meshgroup = {
					bounding = group.bounding,
					material = group.material,
					mode = group.mode,
					vb = {
						start = vb.start,
						num = vb.num,
						handles = handles,
					}
				}
	
				local ib = group.ib
				if ib then
					local v = ib.value
					local create_ib = v.type == "dynamic" and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer
					local startbytes = v.start
					local endbytes = startbytes+v.num-1
					new_meshgroup.ib = {
						start = ib.start,
						num = ib.num,
						handle = create_ib({v.value, startbytes, endbytes}, v.flag),
						updatedata = v.type == "dynamic" and animodule.new_aligned_memory(v.num) or nil
					}
				end
	
				new_meshnode[#new_meshnode+1] = new_meshgroup
			end

			local ibm = meshnode.inverse_bind_matries
			if ibm then
				new_meshnode.inverse_bind_pose 	= animodule.new_bind_pose(ibm.num, ibm.value)
				new_meshnode.joint_remap 		= animodule.new_joint_remap(ibm.joints)
			end
			new_scene[meshname] = new_meshnode
		end
		new_scenes[scenename] = new_scene
	end

	meshscene.scenes = new_scenes
		
	return meshscene
end

return {
    loader = function (filename, data)
        return create_mesh_buffers(data)
    end,
    unloader = function (res, filename)
    end,
}