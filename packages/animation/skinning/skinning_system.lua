local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local assetmgr = import_package "ant.asset"

ecs.component "skinning" {}

local sm = ecs.transform "skinning_material"
-- local function path_table(path, t)
-- 	local last = t
-- 	for m in path:gmatch "[^/]+" do
-- 		local c = last[m]
-- 		if c == nil then
-- 			c = {}
-- 			last[m] = c
-- 		end
-- 		last = c
-- 	end
-- end

function sm.process(e)
	local skinning = e.skinning
	if skinning.type == "GPU" then
		e.material = assetmgr.patch(e.material, {fx={macros={}}})
		local material = e.material
		local macros = material.fx.macros
		macros[#macros+1] = "GPU_SKINNING"
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

		if skinning.type == "CPU" then
			for _, job in ipairs(skinning.jobs) do
				animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap)
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
