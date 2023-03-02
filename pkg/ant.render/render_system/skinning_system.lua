local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

-- skinning system
local icompute = ecs.import.interface "ant.render|icompute"
local skinning_sys = ecs.system "skinning_system"
local r2l_mat<const> = mc.R2L_MAT
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = import_package "ant.render".declmgr
local sk_viewid = viewidmgr.get "skinning"
local bgfx 			= require "bgfx"
local assetmgr  = import_package "ant.asset"


local skinning_material

local function do_skinning_compute(vb_num, skinning_matrices_vb, skinning_in_dynamic_vb, skinning_out_dynamic_vb)
	local dispatchsize = {
		math.floor((vb_num + 63) / 64), 1 , 1
	}
    local dis = {}
	dis.size = dispatchsize

	local sm_buffer = {
		build_stage = 0,
		build_access = "r",
		name = "skinning_matrices_vb",
		layout = declmgr.get "p4".handle,
		handle = skinning_matrices_vb
	}

	local dvb_in_buffer = {
		build_stage = 1,
		build_access = "r",
		name = "skinning_dynamic_vb_in",
		layout = declmgr.get "p40NIf|t40NIf|i40NIf|w40NIf|T40NIf".handle,
		handle = skinning_in_dynamic_vb
	}

	local dvb_out_buffer = {
		build_stage = 2,
		build_access = "w",
		name = "skinning_dynamic_vb_out",
		layout = declmgr.get "p40NIf|t40NIf|T40NIf".handle,
		handle = skinning_out_dynamic_vb		
	}

	local mo = skinning_material.object
	mo:set_attrib("b_skinning_matrices_vb", icompute.create_buffer_property(sm_buffer, "build"))
	mo:set_attrib("b_skinning_in_dynamic_vb", icompute.create_buffer_property(dvb_in_buffer, "build"))
	mo:set_attrib("b_skinning_out_dynamic_vb", icompute.create_buffer_property(dvb_out_buffer, "build"))

	dis.material = mo:instance()
	dis.fx = skinning_material._data.fx
    icompute.dispatch(sk_viewid, dis)
end

function skinning_sys:init()
	skinning_material = assetmgr.resource("/pkg/ant.resources/materials/skinning/skinning.material")
end

function skinning_sys:entity_init()
	local meshskin
	for e in w:select "skinning scene?in meshskin?update render_object?update" do
		if e.meshskin then
			meshskin = e.meshskin
		else
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			if meshskin.skinning_matrices_vb == nil or meshskin.skinning_in_dynamic_vb == nil and meshskin.skinning_out_dynamic_vb == nil then
				local sm = meshskin.skinning_matrices
				local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count())
				meshskin.skinning_matrices_vb = bgfx.create_dynamic_vertex_buffer(memory_buffer, declmgr.get("p4").handle, "r")
				meshskin.skinning_in_dynamic_vb = e.render_object.vb_handle
				local skinning_out_dynamic_vb = bgfx.create_dynamic_vertex_buffer(e.render_object.vb_num, declmgr.get "p40NIf|t40NIf|T40NIf".handle, "w")
				meshskin.skinning_out_dynamic_vb = skinning_out_dynamic_vb
	
				e.render_object.vb_handle = skinning_out_dynamic_vb 
			end
		end
	end
end

function skinning_sys:skin_mesh()
	for e in w:select "meshskin:in scene:update" do
		local skin = e.meshskin.skin
		local skinning_matrices = e.meshskin.skinning_matrices
		local pr = e.meshskin.pose.pose_result
		if pr then
 			local m = r2l_mat
			animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, m)  
		end
	end

	local meshskin
	local worldmat
	for e in w:select "skinning scene?in meshskin?in render_object?update bounding?update" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			e.render_object.worldmat = worldmat
			do_skinning_compute(e.render_object.vb_num, meshskin.skinning_matrices_vb, meshskin.skinning_in_dynamic_vb, meshskin.skinning_out_dynamic_vb)
			if mc.NULL ~= e.bounding.aabb then
				math3d.unmark(e.bounding.scene_aabb)
				e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
			end
		end
	end
end  