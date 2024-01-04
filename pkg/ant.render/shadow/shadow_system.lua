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
local queuemgr  = ecs.require "queue_mgr"

local isc= ecs.require "shadow.shadowcfg"
local icamera   = ecs.require "ant.camera|camera"
local irq       = ecs.require "render_system.renderqueue"
local imaterial = ecs.require "ant.asset|material"
local ivs		= ecs.require "ant.render|visible_state"

local LiSPSM	= require "shadow.LiSPSM"

local csm_matrices			= {math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT)}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))

local INV_Z<const> = true
--TODO: read from setting file
local useLiSPSM<const> = false

local CLEAR_SM_viewid<const> = hwi.viewid_get "csm_fb"
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
				viewid = CLEAR_SM_viewid,
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
	local camera_ref = icamera.create({
			updir 	= mc.YAXIS,
			viewdir = mc.ZAXIS,
			eyepos 	= mc.ZERO_PT,
			frustum = {
				l = -1, r = 1, t = 1, b = -1,
				n = 1, f = 100, ortho = true,
			},
			name = csmname,
			camera_depend = true,
		}, function (e)
			w:extend(e, "camera:update")
			local c = e.camera
			c.Lr	= math3d.ref()
			c.Wv	= math3d.ref()
			c.Wp	= math3d.ref()
			c.Wpv	= math3d.ref()
			c.Wpvl	= math3d.ref()
			c.W		= math3d.ref()

			c.F		= math3d.ref()
			w:submit(e)
		end)
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
		},
	}
end


local shadow_material
local gpu_skinning_material
function shadow_sys:init()
	local fbidx = isc.fb_index()
	local s     = isc.shadowmap_size()
	create_clear_shadowmap_queue(fbidx)
	shadow_material 			= assetmgr.resource "/pkg/ant.resources/materials/predepth.material"
	gpu_skinning_material 		= assetmgr.resource "/pkg/ant.resources/materials/predepth_skin.material"
	for ii=1, isc.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx)
	end

	imaterial.system_attrib_update("s_shadowmap", fbmgr.get_rb(isc.fb_index(), 1).handle)
	imaterial.system_attrib_update("u_shadow_param1", isc.shadow_param1())
	imaterial.system_attrib_update("u_shadow_param2", isc.shadow_param2())
end

local function set_csm_visible(enable)
	for v in w:select "csm visible?out" do
		v.visible = enable
	end
end

function shadow_sys:entity_init()
	for e in w:select "INIT make_shadow directional_light light:in csm_directional_light?update" do
		if w:count "csm_directional_light" > 0 then
			log.warn("Multi directional light for csm shaodw")
		end
		e.csm_directional_light = true
		set_csm_visible(true)
	end
end

function shadow_sys:entity_remove()
	for _ in w:select "REMOVED csm_directional_light" do
		set_csm_visible(false)
	end
end

local function mark_camera_changed(e)
	-- this camera should not generate the change tag
	w:extend(e, "scene_changed?out scene_needchange?out camera_changed?out")
	e.camera_changed = true
	e.scene_changed = false
	e.scene_needchange = false
	w:submit(e)
end

local function update_camera(c, Lv, Lp)
	c.viewmat.m		= Lv
	c.projmat.m		= Lp
	c.infprojmat.m	= Lp
	c.viewprojmat.m	= math3d.mul(Lp, Lv)
end

local function commit_csm_matrices_attribs()
	imaterial.system_attrib_update("u_csm_matrix",			math3d.array_matrix(csm_matrices))
	imaterial.system_attrib_update("u_csm_split_distances",	split_distances_VS)
end

local function M3D(o, n)
	if o then
		math3d.unmark(o)
	end
	return math3d.mark(n)
end

local function calc_light_view_nearfar(intersectpointsLS, sceneaabbLS)
	local intersectaabb = math3d.minmax(intersectpointsLS)
	local PSR_farLS = math3d.index(math3d.array_index(sceneaabbLS, 2), 3)
	local fn, ff = mu.aabb_minmax_index(intersectaabb, 3)
	--check for PSR far plane distance
	ff = math.max(ff, PSR_farLS)
	return fn, ff
end

local function update_shadow_matrices(si, li, c)
	local sp = math3d.projmat(c.viewfrustum)
	local Lv2Ndc = math3d.mul(sp, li.Lv2Cv)

	local intersectpointsLS = math3d.frustum_aabb_intersect_points(Lv2Ndc, si.sceneaabbLS)
	-- for debug
	-- c.intersectpointsLS = M3D(c.intersectpointsLS, intersectpointsLS)
	-- c.Lv2Ndc = M3D(c.Lv2Ndc, Lv2Ndc)
	-- c.sceneaabbLS = M3D(c.sceneaabbLS, si.sceneaabbLS)

	local Lp
	if mc.NULL ~= intersectpointsLS then
		local n, f = calc_light_view_nearfar(intersectpointsLS, si.sceneaabbLS)
		c.frustum.n, c.frustum.f = n, f
		si.nearLS, si.farLS = n, f
		Lp = math3d.projmat(c.frustum, INV_Z)
		if useLiSPSM then
			li.Lp = Lp
			local Wv, Wp = LiSPSM.warp_matrix(si, li, intersectpointsLS)
			Lp = math3d.mul(math3d.mul(math3d.mul(Wp, Wv), li.Lr), Lp)
		end

		local F = isc.calc_focus_matrix(math3d.minmax(intersectpointsLS, Lp))
		Lp 		= math3d.mul(F, Lp)
	else
		Lp		= math3d.projmat(c.frustum, INV_Z)
	end
	update_camera(c, li.Lv, Lp)
end

local function init_light_info(C, D)
    local lightdirWS = math3d.index(D.scene.worldmat, 3)
	local Cv = C.camera.viewmat

	local rightdir, viewdir, camerapos = math3d.index(C.scene.worldmat, 1, 3, 4)

	local Lv = math3d.lookto(mc.ZERO_PT, lightdirWS, rightdir)
	local Lw = math3d.inverse_fast(Lv)

	return {
		Lv			= Lv,
		Lw			= Lw,
		Cv			= Cv,
		Lr			= useLiSPSM and LiSPSM.rotation_matrix(math3d.transform(Lv, viewdir, 0)) or nil,
		Lv2Cv		= math3d.mul(Cv, Lw),
	
		viewdir		= viewdir,
		lightdir	= lightdirWS,
		camerapos	= camerapos,
	}
end

local function build_sceneaabbLS(si, li)
	local PSRLS = math3d.aabb_transform(li.Lv, assert(si.PSR))
	if si.PSC then
		local PSCLS = math3d.aabb_transform(li.Lv, si.PSC)
	
		local PSR_farLS = math3d.index(math3d.array_index(PSRLS, 2), 3)
		local PSC_nearLS = math3d.index(math3d.array_index(PSCLS, 1), 3)
	
		local sceneaabb = math3d.aabb_intersection(PSRLS, PSCLS)
	
		local sminv, smaxv = mu.aabb_minmax(sceneaabb)
		local sminx, sminy = math3d.index(sminv, 1, 2)
		local smaxx, smaxy = math3d.index(smaxv, 1, 2)
	
		return math3d.aabb(math3d.vector(sminx, sminy, PSC_nearLS), math3d.vector(smaxx, smaxy, PSR_farLS))
	end

	return PSRLS
end

function shadow_sys:update_camera_depend()
	local C = irq.main_camera_changed()
	if not C then
		return
	end

	local D = w:first "make_shadow directional_light scene:in"
	if not D then
		return
	end

	w:extend(C, "scene:in camera:in")

	local sb = w:first "shadow_bounding:in".shadow_bounding
	
	local li = init_light_info(C, D)
	sb.sceneaabbLS = build_sceneaabbLS(sb, li)

	local CF = C.camera.frustum
	sb.view_near, sb.view_far = CF.n, CF.f
	local zn, zf = assert(sb.zn), assert(sb.zf)
	local _ = (zn >= 0 and zf > zn) or error(("Invalid near and far after cliped, zn must >= 0 and zf > zn, where zn: %2f, zf: %2f"):format(zn, zf))
	--split bounding zn, zf
	local csmfrustums = isc.split_viewfrustum(zn, zf, CF)

    for e in w:select "csm:in camera_ref:in queue_name:in" do
        local ce<close> = world:entity(e.camera_ref, "scene:update camera:in")	--update scene.worldmat
		ce.scene.worldmat = M3D(ce.scene.worldmat, li.Lw)

        local c = ce.camera
        local csm = e.csm
		c.viewfrustum = csmfrustums[csm.index]
		update_shadow_matrices(sb, li, c)
		mark_camera_changed(ce)

		csm_matrices[csm.index].m = math3d.mul(isc.crop_matrix(csm.index), c.viewprojmat)
		split_distances_VS[csm.index] = c.viewfrustum.f
    end

	commit_csm_matrices_attribs()
end

function shadow_sys:render_preprocess()
	bgfx.touch(CLEAR_SM_viewid)
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
		local hasaabb = e.bounding.aabb ~= mc.NULL
		local receiveshadow = hasaabb and mt.fx.setting.receive_shadow == "on"

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
				castshadow = hasaabb
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
