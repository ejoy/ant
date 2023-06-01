local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local setting	= import_package "ant.settings".setting
local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"

local skinning_sys = ecs.system "skinning_system"

if USE_CS_SKINNING then
	local renderutil= require "util"
	renderutil.default_system(skinning_sys, "skin_mesh")
	return
end

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

-- skinning system

local r2l_mat<const> = mc.R2L_MAT

local function to_m3d_mat_ref(sm, smref)
	math3d.unmark(smref)
	return math3d.mark(math3d.array_matrix_ref(sm:pointer(), sm:count()))
end

function skinning_sys:entity_init()
	for e in w:select "INIT meshskin:in" do
		e.meshskin.sm_matrix_ref = mc.NULL
	end
end

function skinning_sys:entity_remove()
	for e in w:select "REMOVED meshskin:in" do
		math3d.unmark(e.meshskin.sm_matrix_ref)
	end
end

function skinning_sys:skin_mesh()
	for e in w:select "meshskin:in scene:update" do
		local skin = e.meshskin.skin
		local sm = e.meshskin.skinning_matrices
		local pr = e.meshskin.pose.pose_result
		if pr then
			local m = math3d.mul(e.scene.worldmat, r2l_mat)
			animodule.build_skinning_matrices(sm, pr, skin.inverse_bind_pose, skin.joint_remap, m)
			e.meshskin.sm_matrix_ref = to_m3d_mat_ref(sm, e.meshskin.sm_matrix_ref)
		end
	end

	local meshskin
	local worldmat
	for e in w:select "skinning scene?in meshskin?in render_object?update bounding?update skininfo?update eid:in" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			e.render_object.worldmat = meshskin.sm_matrix_ref

			if mc.NULL ~= e.bounding.aabb then
				math3d.unmark(e.bounding.scene_aabb)
				e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
			end
		end
	end
end