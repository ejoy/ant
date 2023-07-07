local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local setting	= import_package "ant.settings".setting
local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"
local imaterial = ecs.import.interface "ant.asset|imaterial"
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

local function mark_ref_matrices(m3d, newm3d)
	math3d.unmark(m3d)
	return math3d.mark(newm3d)
end

local function sm2m3darray(sm, smref)
	local m = math3d.array_matrix_ref(sm:pointer(), sm:count())
	return mark_ref_matrices(smref, m)

end

function skinning_sys:entity_init()
	for e in w:select "INIT meshskin:in" do
		e.meshskin.sm_matrix_ref = mc.NULL
		e.meshskin.prev_sm_matrix_ref = mc.NULL
	end
end

function skinning_sys:entity_remove()
	for e in w:select "REMOVED meshskin:in" do
		math3d.unmark(e.meshskin.sm_matrix_ref)
		math3d.unmark(e.meshskin.prev_sm_matrix_ref)
	end
end



function skinning_sys:skin_mesh()
	for e in w:select "meshskin:in scene:update" do
		local skin = e.meshskin.skin
		local pr = e.meshskin.pose.pose_result
		if pr then
			local m = math3d.mul(e.scene.worldmat, r2l_mat)
			local sm, prev_sm
			if e.meshskin.sm_matrix_ref == mc.NULL then
				sm = e.meshskin.skinning_matrices
				prev_sm = e.meshskin.prev_skinning_matrices
				animodule.build_skinning_matrices(prev_sm, pr, skin.inverse_bind_pose, skin.joint_remap, m)
			else
				sm = e.meshskin.prev_skinning_matrices
				prev_sm = e.meshskin.skinning_matrices		
			end
			animodule.build_skinning_matrices(sm, pr, skin.inverse_bind_pose, skin.joint_remap, m)
			e.meshskin.sm_matrix_ref = sm2m3darray(sm, e.meshskin.sm_matrix_ref)
			e.meshskin.prev_sm_matrix_ref = sm2m3darray(prev_sm, e.meshskin.prev_sm_matrix_ref)	
		end
	end

	local meshskin
	local worldmat
	
	for e in w:select "skinning scene?in meshskin?in" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			w:extend(e, "render_object:update bounding:update visible_state:in")
			e.render_object.worldmat = meshskin.sm_matrix_ref
			if e.visible_state["velocity_queue"] then
				imaterial.set_property(e, "u_prev_model", meshskin.prev_sm_matrix_ref, "velocity_queue")
			end
			if mc.NULL ~= e.bounding.aabb then
				math3d.unmark(e.bounding.scene_aabb)
				e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
			end
		end
	end
end