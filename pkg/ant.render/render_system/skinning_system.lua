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

local function create_skinning_compute(skininfo, vb_num)
	local dispatchsize = {
		math.floor((vb_num + 63) / 64), 1 , 1
	}
    local dis = {}
	dis.size = dispatchsize

	local mo = skinning_material.object
	dis.material = mo:instance()
	dis.fx = skinning_material._data.fx
	return dis
end

local function do_skinning_compute(skininfo)
	local mat = skininfo.dispatch_entity.material
	mat.b_skinning_matrices_vb = skininfo.skinning_matrices_vb
	mat.b_skinning_in_dynamic_vb = skininfo.skinning_in_dynamic_vb
	mat.b_skinning_out_dynamic_vb = skininfo.skinning_out_dynamic_vb
    icompute.dispatch(sk_viewid, skininfo.dispatch_entity)
end

function skinning_sys:init()
	skinning_material = assetmgr.resource("/pkg/ant.resources/materials/skinning/skinning.material")
end

function skinning_sys:entity_init()
	local meshskin
	for e in w:select "INIT skinning:update scene?in meshskin?update render_object?update skininfo?update" do
		if e.meshskin then
			meshskin = e.meshskin
		else
			local sm = meshskin.skinning_matrices
			local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count())
			e.skininfo.skinning_matrices_vb = bgfx.create_dynamic_vertex_buffer(memory_buffer, declmgr.get("p4").handle, "r")
			e.skininfo.skinning_in_dynamic_vb = e.render_object.vb_handle
			local skinning_out_dynamic_vb = bgfx.create_dynamic_vertex_buffer(e.render_object.vb_num, declmgr.get "p40NIf|t40NIf|T40NIf".handle, "w")
			e.skininfo.skinning_out_dynamic_vb = skinning_out_dynamic_vb
			e.skininfo.dispatch_entity = create_skinning_compute(e.skininfo, e.render_object.vb_num)
			e.render_object.vb_handle = skinning_out_dynamic_vb 
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
	for e in w:select "skinning scene?in meshskin?in render_object?update bounding?update skininfo?update" do
		if e.meshskin then
			meshskin = e.meshskin
			worldmat = e.scene.worldmat
		else
			local skininfo = e.skininfo
			assert(meshskin, "Invalid skinning render object, meshskin should create before this object")
			e.render_object.worldmat = worldmat
			local sm = meshskin.skinning_matrices
			local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count(), sm)
			bgfx.update(skininfo.skinning_matrices_vb, 0, memory_buffer)
			do_skinning_compute(skininfo)
			if mc.NULL ~= e.bounding.aabb then
				math3d.unmark(e.bounding.scene_aabb)
				e.bounding.scene_aabb = math3d.mark(math3d.aabb_transform(worldmat, e.bounding.aabb))
			end
		end
	end
end  