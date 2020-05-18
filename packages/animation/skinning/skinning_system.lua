local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local assetmgr 	= import_package "ant.asset"
local fs 		= require "filesystem"

local sm = ecs.transform "skinning_material"

function sm.process_prefab(e)
	if e.skinning_type == "GPU" then
		local fxname = tostring(e.material.fx):match"[^:]+"
		e.material = assetmgr.patch(e.material, {})
		e.material.fx = assetmgr.load(fs.path(fxname):replace_extension ".dynamicfx":string(), {gpu_skinning=true, filename = fxname})
	end
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

function skinning_sys:skin_mesh()
	for _, eid in world:each "skinning" do
		local e = world[eid]
		local skinning = e.skinning
		local skin = skinning.skin
		local skinning_matrices = skinning.skinning_matrices
		local pr = e.pose_result
		animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap)

		if e.skinning_type == "CPU" then
			for _, job in ipairs(skinning.jobs) do
				local handle = job.hwbuffer_handle
				local updatedata = job.updatedata
				for _, part in ipairs(job.parts) do
					animodule.mesh_skinning(skinning_matrices, part.inputdesc, part.outputdesc, part.num, part.influences_count)
				end
	
				bgfx.update(handle, 0, {"!", updatedata:pointer(), 0, job.buffersize})
			end
		end
	end
end
