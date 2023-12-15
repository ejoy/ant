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

function m:follow_scene_update()
	for e in w:select "scene_changed animation animation_changed?out" do
		e.animation_changed = true
	end
	for e in w:select "animation_changed animation:in scene:in" do
		local skinning = e.animation.skinning
		local sm = skinning.matrices
		local matrices = math3d.array_matrix_ref(sm:pointer(), sm:count())
		local mat = math3d.mul(e.scene.worldmat, r2l_mat)
		math3d.unmark(skinning.matrices_id)
		skinning.matrices_id = math3d.mark(math3d.mul_array(mat, matrices))
	end
	w:propagate("scene", "animation_changed")
end

if ENABLE_TAA then
	function m:skin_mesh()
		for e in w:select "animation_changed skinning:in render_object:update visible_state:in" do
			local skinning = e.skinning
			if e.visible_state["velocity_queue"] then
				imaterial.set_property(e, "u_prev_model", skinning.prev_matrices_id or skinning.matrices_id, "velocity_queue")
			end
			if skinning.prev_matrices_id ~= nil then
				math3d.unmark(skinning.prev_matrices_id)
			end
			skinning.prev_matrices_id = math3d.mark(skinning.matrices_id)
			e.render_object.worldmat = skinning.matrices_id
		end
	end
else
	function m:skin_mesh()
		for e in w:select "animation_changed skinning:in render_object:update" do
			e.render_object.worldmat = e.skinning.matrices_id
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
		matrices = ozz.MatrixVector(count),
		matrices_id = mathpkg.constant.NULL,
	}
end

function api.build(models, skinning)
	ozz.BuildSkinningMatrices(skinning.matrices, models, skinning.inverse_bind_pose, skinning.joint_remap)
end

return api
