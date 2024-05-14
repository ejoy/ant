local ecs = ...
local world = ecs.world
local w = world.w

local setting = import_package "ant.settings"
local USE_CS_SKINNING <const> = setting:get "graphic/skinning/use_cs"
if USE_CS_SKINNING then
	return
end
local ENABLE_TAA <const> = setting:get "graphic/postprocess/taa/enable"

local imaterial = ecs.require "ant.render|material"
local ivm		= ecs.require "ant.render|visible_mask"
local mathpkg = import_package "ant.math"
local assetmgr = import_package "ant.asset"
local ozz = require "ozz"
local math3d = require "math3d"

local r2l_mat <const> = mathpkg.constant.R2L_MAT

local m = ecs.system "skinning_system"
local api = {}
local frame = 0

local function is_changed(skinning)
	return frame == skinning.version
end

function m:component_init()
	for e in w:select "INIT skinning feature_set:in" do
        e.feature_set.GPU_SKINNING = true
    end
end

function m:follow_scene_update()
	for e in w:select "skinning:in scene:in" do
		local skinning = e.skinning
		if is_changed(skinning) then
			local sm = skinning.matrices
			local matrices = math3d.array_matrix_ref(sm:pointer(), sm:count())
			local mat = math3d.mul(e.scene.worldmat, r2l_mat)
			math3d.unmark(skinning.matrices_id)
			skinning.matrices_id = math3d.mark(math3d.mul_array(mat, matrices))
		end
	end
end

if ENABLE_TAA then
	function m:skin_mesh()
		for e in w:select "skinning:in render_object:update visible?in" do
			local skinning = e.skinning
			if is_changed(skinning) then
				if e.visible and ivm.check(e, "velocity_queue") then
					imaterial.set_property(e, "u_prev_model", skinning.prev_matrices_id or skinning.matrices_id, "velocity_queue")
				end
				if skinning.prev_matrices_id ~= nil then
					math3d.unmark(skinning.prev_matrices_id)
				end
				skinning.prev_matrices_id = math3d.mark(skinning.matrices_id)
				e.render_object.worldmat = skinning.matrices_id
			end
		end
	end
else
	function m:skin_mesh()
		for e in w:select "skinning:in render_object:update" do
			local skinning = e.skinning
			if is_changed(skinning) then
				e.render_object.worldmat = skinning.matrices_id
			end
		end
	end
end

function api.create(filename, skeleton, obj)
	local skin = assetmgr.resource(filename)
	local count = skin.jointsRemap
		and #skin.jointsRemap
		or skeleton:num_joints()
	if count > 64 then
		error(("skinning matrices are too large, max is 64, %d needed"):format(count))
	end
	obj = obj or {}
	obj.inverseBindMatrices = skin.inverseBindMatrices
	obj.jointsRemap = skin.jointsRemap
	obj.matrices = ozz.MatrixVector(count)
	obj.matrices_id = mathpkg.constant.NULL
	obj.version = 0
	return obj
end

function api.frame()
	frame = frame + 1
end

function api.build(models, skinning)
	ozz.BuildSkinningMatrices(skinning.matrices, models, skinning.inverseBindMatrices, skinning.jointsRemap)
	skinning.version = frame
end

local c = ecs.component "skinning"

function c.remove(v)
	if ENABLE_TAA then
		if v.prev_matrices_id ~= nil then
			math3d.unmark(v.prev_matrices_id)
			v.prev_matrices_id = mathpkg.constant.NULL
		end
	end
	math3d.unmark(v.matrices_id)
	v.matrices_id = mathpkg.constant.NULL
end

return api
