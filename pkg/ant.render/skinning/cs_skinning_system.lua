local ecs 		= ...
local world 	= ecs.world
local w 		= world.w

local setting	= import_package "ant.settings"
local cs_skinning_sys = ecs.system "cs_skinning_system"

local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"
if not USE_CS_SKINNING then
    return
end

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr

local RM        = ecs.require "ant.material|material"

local hwi		= import_package "ant.hwi"
local sk_viewid = hwi.viewid_get "skinning"

local assetmgr  = import_package "ant.asset"

local ozz = require "ozz"
local math3d 	= require "math3d"
local bgfx 		= require "bgfx"

-- skinning system
local icompute = ecs.require "ant.render|compute.compute"

local r2l_mat<const> = mc.R2L_MAT

local skinning_material

local ATTRIB_INDEX_MAPPER<const> = {
	p = 1, i = 2, w = 3, T = 4, n = 5,
}

local function pack_attrib_indices(layout)
	--we should make all the attribute have index in uniforms, but we assume that postion/indices/weights must have, and the 5 indices(include tangent and normal) is fix right now
	-- local LAYOUT_NAMES<const> = {
	-- 	"POSITION",
	-- 	"NORMAL",
	-- 	"TANGENT",
	-- 	"BITANGENT",
	-- 	"COLOR_0",
	-- 	"COLOR_1",
	-- 	"COLOR_2",
	-- 	"COLOR_3",
	-- 	"TEXCOORD_0",
	-- 	"TEXCOORD_1",
	-- 	"TEXCOORD_2",
	-- 	"TEXCOORD_3",
	-- 	"TEXCOORD_4",
	-- 	"TEXCOORD_5",
	-- 	"TEXCOORD_6",
	-- 	"TEXCOORD_7",
	-- 	"JOINTS_0",
	-- 	"WEIGHTS_0",
	-- }

	local indices = {}; for i=1, 3*4 do indices[i] = -1.0 end

	local other_attrib_idx = 6
	local idx = 0
	for l in layout:gmatch "%w+" do
		local _ = idx <= 12 or error (("Too many attirbute in the layout:%s"):format(layout))
		assert(l:sub(2, 2) == '4' and l:sub(6, 6) == 'f')
		local t = l:sub(1, 1)
		local aidx = ATTRIB_INDEX_MAPPER[t]
		if aidx then
			indices[aidx] = idx
		else
			indices[other_attrib_idx] = idx
			other_attrib_idx = other_attrib_idx + 1
		end
		idx = idx + 1
	end

	return {
		math3d.vector(indices[1], indices[2], indices[3], indices[4]),
		math3d.vector(indices[5], indices[6], indices[7], indices[8]),
		math3d.vector(indices[9], indices[10], indices[11], indices[12]),
	}
end

local function create_skinning_compute(skininfo, vb_num, attrib_indices)
	local dispatchsize = {
		math.floor((vb_num + 63) / 64), 1 , 1
	}
    local dis = {}
	dis.size = dispatchsize
	dis.material = RM.create_instance(skinning_material.object)
	local m = dis.material
	m.b_skinning_matrices_vb	= skininfo.skinning_matrices_vb
	m.b_skinning_in_dynamic_vb	= skininfo.skinning_in_dynamic_vb
	m.b_skinning_out_dynamic_vb	= skininfo.skinning_out_dynamic_vb

	m.u_attrib_indices			= attrib_indices
	m.u_skinning_param			= math3d.vector(vb_num, 0.0, 0.0, 0.0)
	dis.fx 						= skinning_material._data.fx
	return dis
end

local function do_skinning_compute(skininfo)
    icompute.dispatch(sk_viewid, skininfo.dispatch_entity)
end

local function get_output_layout(decl)
	local lt = {}
	-- p (T) other attributes
	for ll in decl:gmatch "[%a+%d+]+" do
		local at = ll:sub(1, 1)
		if at == 'p' then
			table.insert(lt, 1, ll)
		elseif at == 'T' then
			table.insert(lt, 2, ll)
		elseif at ~= 'i' and at ~= 'w'then
			lt[#lt+1] = ll
		end
	end

	assert(lt[1]:sub(1, 1) == 'p')
	return table.concat(lt, '|')
end

function cs_skinning_sys:init()
	skinning_material = assetmgr.resource "/pkg/ant.resources/materials/skinning/skinning.material"
end

function cs_skinning_sys:entity_init()
    local meshskin
    for e in w:select "INIT skinning scene?in mesh?in meshskin?update skininfo?update cs_skinning_ready?out" do
        if e.meshskin then
            meshskin = e.meshskin
        else
            assert(e.mesh)

            local sm = meshskin.skinning_matrices
            local memory_buffer = bgfx.memory_buffer(sm:pointer(), 64 * sm:count())

            e.skininfo = {
                skinning_matrices_vb 	= bgfx.create_dynamic_vertex_buffer(memory_buffer, layoutmgr.get("p4").handle, "r"),
                skinning_in_dynamic_vb 	= nil,
                skinning_out_dynamic_vb = nil,
                dispatch_entity         = nil,
            }

            e.cs_skinning_ready = true

            -- e.skininfo.dispatch_entity	= create_skinning_compute(e.skininfo, e.render_object.vb_num, pack_attrib_indices(layout))
            -- e.render_object.vb_handle = skinning_out_dynamic_vb
        end
    end
end

function cs_skinning_sys:entity_ready()
    for e in w:select "cs_skinning_ready mesh:in render_object:update skininfo:update" do
        e.skininfo.skinning_in_dynamic_vb = e.render_object.vb_handle
        local layout = e.mesh.vb.declname
        local output_layout = get_output_layout(layout)
        e.skininfo.skinning_out_dynamic_vb = bgfx.create_dynamic_vertex_buffer(e.render_object.vb_num, layoutmgr.get(output_layout).handle, "w")

        e.skininfo.dispatch_entity	= create_skinning_compute(e.skininfo, e.render_object.vb_num, pack_attrib_indices(layout))

        e.render_object.vb_handle = e.skininfo.skinning_out_dynamic_vb
    end

    w:clear "cs_skinning_ready"
end

function cs_skinning_sys:skin_mesh()
	for e in w:select "animation:in meshskin:in scene:update" do
		local skin = e.meshskin.skin
		local skinning_matrices = e.meshskin.skinning_matrices
		local pr = e.animation.models
		if pr then
			ozz.BuildSkinningMatrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, r2l_mat)
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
            local skininfo = e.skininfo
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

function cs_skinning_sys:entity_remove()
    for e in w:select "REMOVED skininfo:in" do
        local skininfo = e.skininfo
        bgfx.destroy(skininfo.skinning_matrices_vb)
        --skinning_in_dynamic_vb shoule be released by mesh manager
        --bgfx.destroy(skininfo.skinning_in_dynamic_vb)
        bgfx.destroy(skininfo.skinning_out_dynamic_vb)
    end
end