local ecs = ...
local world = ecs.world
local w = world.w

local setting = import_package "ant.settings"
local USE_CS_SKINNING <const> = setting:get "graphic/skinning/use_cs"
if USE_CS_SKINNING then
	return
end
local ENABLE_TAA <const> = setting:get "graphic/postprocess/taa/enable"

local imaterial = ecs.require "ant.asset|material"
local mathpkg = import_package "ant.math"
local assetmgr = import_package "ant.asset"
local ozz = require "ozz"
local math3d = require "math3d"

local r2l_mat <const> = mathpkg.constant.R2L_MAT

local m = ecs.system "skinning_system"
local api = {}

local function skin_mesh(meshskin, worldmat)
	local sm = meshskin.skinning_matrices
	local mat = math3d.mul(worldmat, r2l_mat)
	local matrices = math3d.array_matrix_ref(sm:pointer(), sm:count())
	return math3d.mul_array(mat, matrices)
end

if ENABLE_TAA then
	function m:skin_mesh()
		for e in w:select "animation:in render_object:update scene:in visible_state:in" do
			local meshskin = e.animation.meshskin
			local matrices = math3d.alive(skin_mesh(meshskin, e.scene.worldmat))
			if e.visible_state["velocity_queue"] then
				imaterial.set_property(e, "u_prev_model", meshskin.sm_matrix_ref or matrices, "velocity_queue")
			end
			meshskin.sm_matrix_ref = matrices
			e.render_object.worldmat = matrices
		end
	end
else
	function m:skin_mesh()
		for e in w:select "animation:in render_object:update scene:in" do
			local meshskin = e.animation.meshskin
			e.render_object.worldmat = skin_mesh(meshskin, e.scene.worldmat)
		end
	end
end

function api.create(filename, skeleton)
	local skin = assetmgr.resource(filename)
	local count = skin.joint_remap
		and #skin.joint_remap
		or skeleton:num_joints()
	if count > 64 then
		error(("skinning matrices are too large, max is 128, %d needed"):format(count))
	end
	return {
		inverse_bind_pose = skin.inverse_bind_pose,
		joint_remap = skin.joint_remap,
		skinning_matrices = ozz.MatrixVector(count),
	}
end

function api.build(models, meshskin)
	ozz.BuildSkinningMatrices(meshskin.skinning_matrices, models, meshskin.inverse_bind_pose, meshskin.joint_remap)
end

return api
