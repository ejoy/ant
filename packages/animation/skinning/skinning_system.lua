local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local sm = ecs.transform "skinning_material"

function sm.process_prefab(e)
	if e.animation and e.skeleton then
		e._cache_prefab.material_setting.skinning = "GPU"
	end
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

local iom = world:interface "ant.objcontroller|obj_motion"

function skinning_sys:skin_mesh()
	for e in w:select "pose_result:in skinning:in" do
		local skinning = e.skinning
		local skin = skinning.skin
		local skinning_matrices = skinning.skinning_matrices
		local pr = e.pose_result
		animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, iom.worldmat(e))
	end
end
