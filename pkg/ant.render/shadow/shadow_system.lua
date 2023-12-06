local ecs   = ...
local world = ecs.world
local w     = world.w

local shadow_sys = ecs.system "shadow_system2"

local setting	= import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
if not ENABLE_SHADOW then
    return
end

local assetmgr  = import_package "ant.asset"
local hwi       = import_package "ant.hwi"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local RM        = ecs.require "ant.material|material"
local R         = world:clibs "render.render_material"
local bgfx      = require "bgfx"
local math3d    = require "math3d"

local fbmgr     = require "framebuffer_mgr"
local queuemgr  = require "queue_mgr"

local ishadowcfg= ecs.require "shadow.shadowcfg"
local icamera   = ecs.require "ant.camera|camera"
local irq       = ecs.require "render_system.render_queue"
local imaterial = ecs.require "ant.asset|material"

local LiSPSM	= require "shadow.LiSPSM"

local csm_matrices			= {math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT)}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))

local function create_clear_shadowmap_queue(fbidx)
	local rb = fbmgr.get_rb(fbidx, 1)
	local ww, hh = rb.w, rb.h
	world:create_entity{
		policy = {
			"ant.render|postprocess_queue",
		},
		data = {
			render_target = {
                clear_state = {
                    depth = 0,
                    clear = "D",
                },
				fb_idx = fbidx,
				viewid = hwi.viewid_get "csm_fb",
				view_rect = {x=0, y=0, w=ww, h=hh},
			},
			need_touch = true,
			clear_sm = true,
			queue_name = "clear_sm",
		}
	}
end

local function create_csm_entity(index, vr, fbidx)
	local csmname = "csm" .. index
	local queuename = csmname .. "_queue"
	local camera_ref = icamera.create {
			updir 	= mc.YAXIS,
			viewdir = mc.ZAXIS,
			eyepos 	= mc.ZERO_PT,
			frustum = {
				l = -1, r = 1, t = -1, b = 1,
				n = 1, f = 100, ortho = true,
			},
			name = csmname
		}
	world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|csm_queue",
		},
		data = {
			csm = {
				index = index,
			},
			camera_ref = camera_ref,
			render_target = {
				viewid = hwi.viewid_get(csmname),
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				clear_state = {
					clear = "",
				},
				fb_idx = fbidx,
			},
			visible = false,
			queue_name = queuename,
			[queuename] = true,
			camera_depend = true
		},
	}
end


local shadow_material
local gpu_skinning_material
function shadow_sys:init()
	local fbidx = ishadowcfg.fb_index()
	local s     = ishadowcfg.shadowmap_size()
	create_clear_shadowmap_queue(fbidx)
	shadow_material 			= assetmgr.resource "/pkg/ant.resources/materials/predepth.material"
	gpu_skinning_material 		= assetmgr.resource "/pkg/ant.resources/materials/predepth_skin.material"
	for ii=1, ishadowcfg.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx)
	end

	imaterial.system_attrib_update("s_shadowmap", fbmgr.get_rb(ishadowcfg.fb_index(), 1).handle)
	imaterial.system_attrib_update("u_shadow_param1", ishadowcfg.shadow_param())
	imaterial.system_attrib_update("u_shadow_param2", ishadowcfg.shadow_param2())
end

local function merge_visible_bounding(M, aabb, e, queuemask)
	local ro = e.render_object
	if 0 == (queuemask & ro.cull_masks) and
		0 ~= (queuemask & ro.visible_masks) then
		aabb = math3d.merge(aabb, math3d.aabb_transform(M, e.bounding.aabb))
	end

	return aabb
end

local function build_PSR(Lv, queuemask)
	local aabb = math3d.aabb()
	for e in w:select "receive_shadow render_object:in" do
		merge_visible_bounding(Lv, aabb, e, queuemask)
	end
	return aabb
end

local function build_PSC(Lv, queuemask)
	local aabb = math3d.aabb()
	for e in w:select "cast_shadow render_object:in bounding:in" do
		merge_visible_bounding(Lv, aabb, e, queuemask)
	end

	return aabb
end

local function merge_PSC_and_PSR(PSC, PSR)
	local minv, maxv = math3d.array_index(math3d.aabb_merge(PSC, PSR), 1, 2)
	local PSC_minz = math3d.index(math3d.array_index(PSC, 1), 3)
	local PSR_maxz = math3d.index(math3d.array_index(PSR, 2), 3)
	--because PSR_minz/PSC_maxz is no meanning, caster is far than receive, it's shadow can not be test by any visible object
	minv = math3d.set_index(minv, 3, PSC_minz)
	maxv = math3d.set_index(maxv, 3, PSR_maxz)
	return math3d.aabb(minv, maxv)
end

local function frustum_points(M, n, f)
	return {
		math3d.tranform(M, math3d.vector(-1.0,-1.0, n, 1.0), 1),	-- 1
		math3d.tranform(M, math3d.vector(-1.0, 1.0, n, 1.0), 1),	-- 2
		math3d.tranform(M, math3d.vector( 1.0,-1.0, n, 1.0), 1),	-- 3
		math3d.tranform(M, math3d.vector( 1.0, 1.0, n, 1.0), 1),	-- 4
		math3d.tranform(M, math3d.vector(-1.0,-1.0, f, 1.0), 1),	-- 5
		math3d.tranform(M, math3d.vector(-1.0, 1.0, f, 1.0), 1),	-- 6
		math3d.tranform(M, math3d.vector( 1.0 -1.0, f, 1.0), 1),	-- 7
		math3d.tranform(M, math3d.vector( 1.0, 1.0, f, 1.0), 1),	-- 8
	}
end

local BOX_TRIANGLES_INDICES = {}

local function quad2tri(indices, i0, i1, i2, i3)
	indices[#indices+1] = {i0, i1, i2}
	indices[#indices+1] = {i1, i3, i0}
end

quad2tri(BOX_TRIANGLES_INDICES, 5, 6, 1, 2) -- left
quad2tri(BOX_TRIANGLES_INDICES, 3, 4, 7, 8) -- right
quad2tri(BOX_TRIANGLES_INDICES, 2, 6, 4, 8) -- top
quad2tri(BOX_TRIANGLES_INDICES, 3, 7, 1, 5) -- bottom
quad2tri(BOX_TRIANGLES_INDICES, 1, 2, 3, 4) -- near
quad2tri(BOX_TRIANGLES_INDICES, 5, 6, 7, 8) -- far

local BOX_RAYS_INDICES<const> = {
	{1, 2}, {2, 3}, {3, 4}, {4, 1},
	{5, 6}, {6, 7}, {7, 8}, {8, 5},

	{1, 5}, {2, 6}, {3, 7}, {4, 8},
}

local function segment_iter(points)
	local i = 0
	return function (t)
		i = i+1
		if i <= #BOX_RAYS_INDICES then
			local s = BOX_RAYS_INDICES[i]
			local i0, i1 = s[1], s[2]
			return t[s[1]], t[i1]
		end
	end, points
end

local function tri_iter(points)
	local i = 0
	local len<const> = #BOX_TRIANGLES_INDICES*2
	return function (t)
		i = i + 1
		if i <= len then
			local ii = i // 2
			local si = i % 2
			local tri = BOX_TRIANGLES_INDICES[ii][si]
			local t0, t1, t2 = tri[1], tri[2], tri[3]
			return points[t0], points[t1], points[t2]
		end
	end, points
end

local function frustum_interset_aabb(M, aabbLS, nearCS, farCS)
	local nearLS, farLS = math.maxinteger, -math.maxinteger

	local function update_nearfar(p)
		local z = math3d.index(p, 3)
		nearLS = math.min(nearLS, z)
		farLS = math.min(farLS, z)
		return p
	end

	local cornersLS = frustum_points(M, nearCS, farCS)
	local verticesLS = {}
	for _, corner in ipairs(cornersLS) do
		if math3d.aabb_test_point(corner, aabbLS) >= 0 then
			verticesLS[#verticesLS+1] = update_nearfar(corner)
		end
	end

	local triangles = {}
	for v0, v1, v2 in tri_iter(cornersLS) do
		triangles[#triangles+1] = v0
		triangles[#triangles+1] = v1
		triangles[#triangles+1] = v2
	end

	for s0, s1 in segment_iter(math3d.aabb_points(aabbLS)) do
		for i=1, #triangles, 3 do
			local p = mu.segment_triangle(s0, s1, triangles[i], triangles[i+1], triangles[i+2])
			if p then
				verticesLS[#verticesLS+1] = update_nearfar(p)
			end
		end
	end

	return verticesLS, nearLS, farLS
end

local function mark_camera_changed(e)
	-- this camera should not generate the change tag
	w:extend(e, "scene_changed?out scene_needchange?out camera_changed?out")
	e.camera_changed = true
	e.scene_changed = false
	e.scene_needchange = false
	w:submit(e)
end

local function calc_focus_matrix(M, verticesLS)
	local sx, sy = 1, 1
	local tx, ty = 0, 0

	local aabb = math3d.aabb()
	for _, v in ipairs(verticesLS) do
		local p = math3d.transform(M, v, 1)
		aabb = math3d.aabb_append(p)
	end

	-- extents = maxv - minv
	-- center = (maxv+minv) * 0.5
	local center, extents = math3d.aabb_center_extents(aabb)

	local ex, ey = math3d.index(extents, 1, 2)
	sx, sy = 2.0 / ex, 2.0 / ey
	tx, ty = math3d.index(center, 1, 2)
	-- inverse scale to translation
	tx, ty = -sx * tx, -sy * ty

	return math3d.matrix(
		sx,  0.0, 0.0, 0.0,
		0.0, sy,  0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		tx,  ty,  0.0, 1.0)
end

local function update_camera(c, Lv, Lp, Lr, Wv, Wp, verticesLS)
	local function M(which, n)
		math3d.unmark(c[which])
		c[which] = math3d.mark(n)
	end

	M("viewmat", 	Lv)
	M("porjmat", 	Lp)
	M("viewprojmat",math3d.mul(Lv, Lp))

	M("Lr", 		Lr)
	M("Wv", 		Wv)
	M("Wp", 		Wp)
	M("Wpv", 		math3d.mul(Wp, Wv))
	M("Wpvl", 		math3d.mul(c.Wpv, Lr))
	M("W", 			math3d.mul(c.Wpvl, c.viewprojgmat))

	local F = calc_focus_matrix(c.W, verticesLS)
	M("F",			F)
	M("FinalMat",	math3d.mul(c.F, c.W))
end

local function commit_csm_matrices_attribs()
	imaterial.system_attrib_update("u_csm_matrix",			math3d.array_matrix(csm_matrices))
	imaterial.system_attrib_update("u_csm_split_distances",	split_distances_VS)
end

function shadow_sys:update_camera_depend()
	local dl = w:first "csm_directional_light scene_changed?in scene:in"
	if dl then
		local mq = w:first "main_queue camera_ref:in"
		local ce <close> = world:entity(mq.camera_ref, "camera_changed?in camera:in scene:in")
		if dl.scene_changed or ce.camera_changed then
			commit_csm_matrices_attribs()
		end
	end
end

function shadow_sys:refine_camera()
    local C = w:first "camera_changed"
    if not C then
        return
    end
    w:extend(C, "eid:in")
    if C.eid ~= irq.main_camera() then
        return 
    end

    w:extend(C, "camera:in")

	local dl = w:first "make_shadow directional_light scene:in"
	local lightdirWS = math3d.index(dl.scene.worldmat, 3)

	local rightdir, viewdir = math3d.index(C.worldmat, 1, 3)
	local Lv = math3d.lookat(lightdirWS, mc.ZERO_PT, rightdir)

	local queuemask = queuemgr.queue_mask "csm1_queue" | queuemgr.queue_mask "csm2_queue" | queuemgr.queue_mask "csm3_queue" | queuemgr.queue_mask "csm4_queue"
	local PSR, PSC = build_PSR(Lv, queuemask), build_PSC(Lv, queuemask)
	local sceneaabb = merge_PSC_and_PSR(PSC, PSR)

	local M = math3d.mul(Lv, math3d.inverse(C.camera.viewprojmat))

	local viewdirLS = math3d.transform(Lv, viewdir, 0)
	local Lr = LiSPSM.rotation_matrix(viewdirLS)

	local Cv = C.camera.viewmat

	--TODO: hardcode
	local split_ratio = {
		{0.0,  0.1},
		{0.1,  0.25},
		{0.25, 0.5},
		{0.5,  1.0},
	}

	local zn, zf = C.camera.frustum.n, C.camera.frustum.f

	--TODO: need get from setting file
	local nearHit, farHit = 1, 100

    for e in w:select "csm:in camera_ref:in queue_name:in" do
        local ce<close> = world:entity(e.camera_ref, "camera:in")
        local c = ce.camera
        local csm = ce.csm

		local sr	= split_ratio[csm.index]
		local verticesLS, nearLS, farLS	= frustum_interset_aabb(M, sceneaabb, sr[1], sr[2])

		local Lp	= math3d.projmat{l=-1, r=1, t=1, b=-1, n=nearLS, f=farLS, ortho=true}
		local Lrp	= math3d.mul(Lr, Lp)
		local camerainfo = {
			Lv				= Lv,
			Lrp				= Lrp,
			Lrpv			= math3d.mul(Lrp, Lv),
			Cv				= Cv,
			viewdirWS		= viewdir,
			lightdirWS		= lightdirWS,
			zn				= zn,
			zf				= zf,
			nearHit			= nearHit,
			farHit			= farHit,
		}
		local Wv, Wp = LiSPSM.warp_matrix(camerainfo, verticesLS)
		update_camera(c, Lv, Lp, Lr, Wv, Wp, verticesLS)

		mark_camera_changed(ce)

		csm_matrices[csm.index].m = math3d.mul(ishadowcfg.crop_matrix(csm.index), c.FinalMat)
		split_distances_VS[csm.index] = zn + (zf-zn) * (sr[2] - sr[1])	--TODO: need remove
    end
end

local function which_material(e, matres)
	if matres.fx.depth then
		return matres
	end
    w:extend(e, "skinning?in")
    return e.skinning and gpu_skinning_material or shadow_material
end


--front face is 'CW', when building shadow we need to remove front face, it's 'CW'
local CULL_REVERSE<const> = {
	CCW		= "CW",
	CW		= "CCW",
	NONE	= "CCW",
}

local function create_depth_state(srcstate, dststate)
	local s, d = bgfx.parse_state(srcstate), bgfx.parse_state(dststate)
	d.PT = s.PT
	local c = s.CULL or "NONE"
	d.CULL = CULL_REVERSE[c]
	d.DEPTH_TEST = "GREATER"

	return bgfx.make_state(d)
end

function shadow_sys:follow_scene_update()
	for e in w:select "visible_state_changed visible_state:in material:in cast_shadow?out" do
		local castshadow
		if e.visible_state["cast_shadow"] then
			local mt = assetmgr.resource(e.material)
			castshadow = mt.fx.setting.cast_shadow == "on"
		end

		e.cast_shadow		= castshadow
	end
end


function shadow_sys:update_filter()
    for e in w:select "filter_result visible_state:in render_object:in material:in bounding:in cast_shadow?out receive_shadow?out" do
		local mt = assetmgr.resource(e.material)
		local receiveshadow = mt.fx.setting.shadow_receive == "on"

		local castshadow
		if e.visible_state["cast_shadow"] then
			local ro = e.render_object

			local mat_ptr
			if mt.fx.setting.cast_shadow == "on" then
				w:extend(e, "filter_material:in")
				local dstres = which_material(e, mt)
				local fm = e.filter_material
				local mi = RM.create_instance(dstres.depth.object)
				assert(not fm.main_queue:isnull())
				mi:set_state(create_depth_state(fm.main_queue:get_state(), dstres.state))
				fm["csm1_queue"] = mi
				fm["csm2_queue"] = mi
				fm["csm3_queue"] = mi
				fm["csm4_queue"] = mi
	
				mat_ptr = mi:ptr()
				e.cast_shadow = true
			end
	
			R.set(ro.rm_idx, queuemgr.material_index "csm1_queue", mat_ptr)
			R.set(ro.rm_idx, queuemgr.material_index "csm2_queue", mat_ptr)
			R.set(ro.rm_idx, queuemgr.material_index "csm3_queue", mat_ptr)
			R.set(ro.rm_idx, queuemgr.material_index "csm4_queue", mat_ptr)
		end
		e.cast_shadow		= castshadow
		e.receive_shadow	= receiveshadow
	end
end
