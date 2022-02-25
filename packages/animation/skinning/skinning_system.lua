local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

-- skinning system
local skinning_sys = ecs.system "skinning_system"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local r2l_mat<const> = mc.R2L_MAT
function skinning_sys:skin_mesh()
	for e in w:select "pose_result:in skinning:in id:in" do
		local skinning = e.skinning
		local skin = skinning.skin
		local skinning_matrices = skinning.skinning_matrices
		local pr = e.pose_result

		local m = math3d.mul(iom.worldmat(e.id), r2l_mat)
		animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, m)
	end
end
