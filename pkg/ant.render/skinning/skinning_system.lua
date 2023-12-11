local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local setting	= import_package "ant.settings"
local USE_CS_SKINNING<const>	= setting:get "graphic/skinning/use_cs"
if USE_CS_SKINNING then
	return
end

local ENABLE_TAA<const>			= setting:get "graphic/postprocess/taa/enable"

local imaterial = ecs.require "ant.asset|material"
local skinning_sys = ecs.system "skinning_system"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local ozz = require "ozz"
local math3d 	= require "math3d"

local r2l_mat <const> = mc.R2L_MAT

local build_skinning_matrices = ENABLE_TAA and
	function (e, pr, skin)
		local m = math3d.mul(e.scene.worldmat, r2l_mat)
		if e.meshskin.sm_matrix_ref == nil then
			local sm = e.meshskin.skinning_matrices
			ozz.BuildSkinningMatrices(sm, pr.models, skin.inverse_bind_pose, skin.joint_remap, m)
			e.meshskin.prev_sm_matrix_ref = math3d.array_matrix_ref(sm:pointer(), sm:count())
			e.meshskin.sm_matrix_ref = math3d.array_matrix_ref(sm:pointer(), sm:count())
		else
			do
				local tmp = e.meshskin.prev_skinning_matrices
				e.meshskin.prev_skinning_matrices = e.meshskin.skinning_matrices
				e.meshskin.skinning_matrices = tmp
			end
			local prev_sm = e.meshskin.prev_skinning_matrices
			local sm = e.meshskin.skinning_matrices
			ozz.BuildSkinningMatrices(sm, pr.models, skin.inverse_bind_pose, skin.joint_remap, m)
			e.meshskin.prev_sm_matrix_ref = math3d.array_matrix_ref(prev_sm:pointer(), prev_sm:count())
			e.meshskin.sm_matrix_ref = math3d.array_matrix_ref(sm:pointer(), sm:count())
		end
	end or
	function (e, pr, skin)
		local m = math3d.mul(e.scene.worldmat, r2l_mat)
		local sm = e.meshskin.skinning_matrices
		ozz.BuildSkinningMatrices(sm, pr.models, skin.inverse_bind_pose, skin.joint_remap, m)
		e.meshskin.sm_matrix_ref = math3d.array_matrix_ref(sm:pointer(), sm:count())
	end

local function update_aabb(e, meshskin, worldmat)
	assert(meshskin, "Invalid skinning render object, meshskin should create before this object")

	w:extend(e, "render_object:update bounding:update")
	e.render_object.worldmat = meshskin.sm_matrix_ref
	if mc.NULL ~= e.bounding.aabb then
		math3d.unmark(e.bounding.scene_aabb)
		e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
	end
end

local update_skin_entity_uniforms = ENABLE_TAA and function (e, meshskin, worldmat)
	update_aabb(e, meshskin, worldmat)
	w:extend(e, "visible_state:in")
	if e.visible_state["velocity_queue"] then
		imaterial.set_property(e, "u_prev_model", meshskin.prev_sm_matrix_ref, "velocity_queue")
	end
end or update_aabb

function skinning_sys:skin_mesh()
	for e in w:select "meshskin:in scene:update" do
		local skin = e.meshskin.skin
		local pr = e.meshskin.pose.pose_result
		if pr then
			build_skinning_matrices(e, pr, skin)
		end
	end

	local meshskin
	local worldmat
	for e in w:select "skinning scene?in meshskin?in" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			update_skin_entity_uniforms(e, meshskin, worldmat)
		end
	end
end
