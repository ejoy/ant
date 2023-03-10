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
local cs_skinning = false
--cs_skinning: skinning_system export_meshbin ext_meshbin inputs.sh

local skinning_material

local function create_skinning_compute(skininfo, vb_num)
	local dispatchsize = {
		math.floor((vb_num + 63) / 64), 1 , 1
	}
    local dis = {}
	dis.size = dispatchsize

	local mo = skinning_material.object
	dis.material = mo:instance()
	local mat = dis.material
	mat.b_skinning_matrices_vb = skininfo.skinning_matrices_vb
	mat.b_skinning_in_dynamic_vb = skininfo.skinning_in_dynamic_vb
	mat.b_skinning_out_dynamic_vb = skininfo.skinning_out_dynamic_vb
	mat.u_skinning_param = math3d.vector(skininfo.decl_cnt, 0, 0, 0)
	dis.fx = skinning_material._data.fx
	return dis
end

local function do_skinning_compute(skininfo)
    icompute.dispatch(sk_viewid, skininfo.dispatch_entity)
end

local function get_output_layout(decl)
	local layout = "p40NIf|T40NIf"
	for ll in string.gmatch(decl, "[%w]+") do
		if ll ~= "p40NIf" and ll ~= "T40NIf" and ll ~= "i40NIf" and ll~= "w40NIf" then
			layout = layout .. '|' .. ll
		end
	end
	return layout
end

function skinning_sys:init()
	if cs_skinning == true then
		skinning_material = assetmgr.resource("/pkg/ant.resources/materials/skinning/skinning.material")
	end
end

function skinning_sys:entity_init()
	if cs_skinning == true then
		local meshskin
		for e in w:select "INIT skinning:update scene?in mesh?in meshskin?update render_object?update skininfo?update" do
			if e.meshskin then
				meshskin = e.meshskin
			else
				assert(e.mesh)
				local decl = e.mesh.vb.declname
				local _, cnt = string.gsub(decl, '|', "")
				cnt = cnt + 1 - 2
				local output_layout = get_output_layout(decl)
				local sm = meshskin.skinning_matrices
				local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count())
				local skinning_out_dynamic_vb = bgfx.create_dynamic_vertex_buffer(e.render_object.vb_num, declmgr.get(output_layout).handle, "w")
				e.skininfo = {
					skinning_matrices_vb 	= bgfx.create_dynamic_vertex_buffer(memory_buffer, declmgr.get("p4").handle, "r"),
					skinning_in_dynamic_vb 	= e.render_object.vb_handle,
					skinning_out_dynamic_vb = skinning_out_dynamic_vb,
					decl_cnt                = cnt
				}
	
				e.skininfo.dispatch_entity	= create_skinning_compute(e.skininfo, e.render_object.vb_num)
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
			local m = math3d.mul(e.scene.worldmat, r2l_mat)
			animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, m)  
		end
	end

	local meshskin
	local worldmat
	for e in w:select "skinning scene?in meshskin?in render_object?update bounding?update skininfo?update" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			if cs_skinning == true then
				local skininfo = e.skininfo
				--e.render_object.worldmat = worldmat
				e.render_object.worldmat = mc.IDENTITY_MAT
				local sm = meshskin.skinning_matrices
				local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count(), sm)
				bgfx.update(skininfo.skinning_matrices_vb, 0, memory_buffer)
				do_skinning_compute(skininfo)
			else
				local sm = meshskin.skinning_matrices
				e.render_object.worldmat = math3d.array_matrix_ref(sm:pointer(), sm:count())							
			end

			if mc.NULL ~= e.bounding.aabb then
				math3d.unmark(e.bounding.scene_aabb)
				e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
			end
		end
	end
end  

function skinning_sys:entity_remove()
	if cs_skinning == true then
		for e in w:select "REMOVED skininfo:in" do
			local skininfo = e.skininfo
			bgfx.destroy(skininfo.skinning_matrices_vb)
			bgfx.destroy(skininfo.skinning_in_dynamic_vb)
			bgfx.destroy(skininfo.skinning_out_dynamic_vb)
		end
	end
end