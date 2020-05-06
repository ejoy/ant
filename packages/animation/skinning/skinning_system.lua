local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

ecs.component "skinning" {}

-- skinning system
local skinning_sys = ecs.system "skinning_system"

local function build_skinning_matrices(skinningjob, aniresult, skin)
	local skinning_matrices = skinningjob.skinning_matrices
	if skinning_matrices == nil then
		skinning_matrices = animodule.new_bind_pose(aniresult:count())
		skinningjob.skinning_matrices = skinning_matrices
	end

	animodule.build_skinning_matrices(skinning_matrices, aniresult, skin.inverse_bind_pose, skin.joint_remap)
	return skinning_matrices
end

function skinning_sys:skin_mesh()
	for _, eid in world:each "skinning" do
		local e = world[eid]
		local skincomp = e.skinning
		local skin = skincomp.skin
		local pr = e.pose_result

		for _, job in ipairs(skincomp.jobs) do
			local skinning_matrices = build_skinning_matrices(job, pr, skin)
			local handle = job.hwbuffer_handle
			local updatedata = job.updatedata
			for _, part in ipairs(job.parts) do
				animodule.mesh_skinning(skinning_matrices, part.inputdesc, part.outputdesc, part.num, part.influences_count)
			end

			bgfx.update(handle, 0, {"!", updatedata:pointer(), 0, job.buffersize})
		end
	end
end
