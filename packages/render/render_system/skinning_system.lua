local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

-- skinning system
local skinning_sys = ecs.system "skinning_system"
local r2l_mat<const> = mc.R2L_MAT
function skinning_sys:skin_mesh()
	for e in w:select "meshskin:in scene:in" do
		local skin = e.meshskin.skin
		local skinning_matrices = e.meshskin.skinning_matrices
		local pr = e.meshskin.pose.pose_result
		if pr then
			local m = math3d.mul(e.scene.worldmat, r2l_mat)
			animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, m)
		end
	end

	local meshskin
	for e in w:select "skinning meshskin?in render_object?in" do
		if e.meshskin then
			meshskin = e.meshskin
		else
			local sm = meshskin.skinning_matrices
			e.render_object.worldmat = math3d.array_matrix_ref(sm:pointer(), sm:count())
		end
	end
end
