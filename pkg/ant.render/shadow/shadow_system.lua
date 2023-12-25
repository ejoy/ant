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
local sampler	= import_package "ant.render.core".sampler
local layoutmgr = require "vertexlayout_mgr"

local RM        = ecs.require "ant.material|material"
local R         = world:clibs "render.render_material"
local Q			= world:clibs "render.queue"
local bgfx      = require "bgfx"
local math3d    = require "math3d"

local fbmgr     = require "framebuffer_mgr"
local queuemgr  = ecs.require "queue_mgr"

local ishadowcfg= ecs.require "shadow.shadowcfg"
local icamera   = ecs.require "ant.camera|camera"
local irq       = ecs.require "render_system.renderqueue"
local imaterial = ecs.require "ant.asset|material"
local ivs		= ecs.require "ant.render|visible_state"

local LiSPSM	= require "shadow.LiSPSM"

local csm_matrices			= {math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT)}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))

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

local function merge_visible_bounding(M, aabb, obj, bounding, queue_index)
	if Q.check(obj.visible_idx, queue_index) and mc.NULL ~= bounding.scene_aabb then
		if M then
			aabb = math3d.aabb_merge(aabb, math3d.aabb_transform(M, bounding.scene_aabb))
		else
			aabb = math3d.aabb_merge(aabb, bounding.scene_aabb)
		end
	end

	return aabb
end

local function build_aabb(queue_index, M, tag)
	local aabb = math3d.aabb()
	for e in w:select(("%s render_object_visible render_object:in bounding:in"):format(tag)) do
		aabb = merge_visible_bounding(M, aabb, e.render_object, e.bounding, queue_index)
	end

	-- for e in w:select"render_object_visible render_object:in bounding:in" do
	-- 	aabb = merge_visible_bounding(M, aabb, e.render_object, e.bounding, queue_index)
	-- end

	for e in w:select "hitch_visible hitch:in bounding:in" do
		aabb = merge_visible_bounding(M, aabb, e.hitch, e.bounding, queue_index)
	end

	return aabb
end

local function build_PSR(queue_index, M)
	return build_aabb(queue_index, M, "receive_shadow")
end

local function build_PSC(queue_index, M)
	return build_aabb(queue_index, M, "cast_shadow")
end

local function merge_PSC_and_PSR(PSC, PSR)
	local PSR_near, PSR_far = mu.aabb_minmax_index(PSR, 3)
	local PSC_near, PSC_far = mu.aabb_minmax_index(PSC, 3)

	local sceneaabb = math3d.aabb_intersection(PSR, PSC)

	local sminv, smaxv = mu.aabb_minmax(sceneaabb)
	local sminx, sminy = math3d.index(sminv, 1, 2)
	local smaxx, smaxy = math3d.index(smaxv, 1, 2)

	local USE_CASTER_FAR<const> = true
	if USE_CASTER_FAR then
		return math3d.aabb(math3d.vector(sminx, sminy, PSC_far), math3d.vector(smaxx, smaxy, PSC_near))
	else
		return math3d.aabb(math3d.vector(sminx, sminy, PSR_far), math3d.vector(smaxx, smaxy, PSC_near))
	end
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

assert(#BOX_TRIANGLES_INDICES == 6*2)

local BOX_SEGMENT_INDICES<const> = {
	{1, 2}, {2, 4}, {4, 3}, {3, 1},
	{5, 6}, {6, 8}, {8, 7}, {7, 5},

	{1, 5}, {2, 6}, {3, 7}, {4, 8},
}

assert(#BOX_SEGMENT_INDICES == 4*3)

local function aabb_near_far(aabb)
	local minv, maxv = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
	return math3d.index(minv, 3), math3d.index(maxv, 3)
end

local function rays_planes(rays, planes, resultop)
	for _, r in ipairs(rays) do
		for i=1, math3d.array_size(planes) do
			local p = math3d.array_index(planes, i)
			local t = math3d.plane_ray(r.o, r.d, p)
			if t and 0 <= t and t <= 1.0 then
				local pt = math3d.muladd(r.d, t, r.o)
				resultop(pt)
			end
		end
	end
end

local function build_box_rays(boxpoints)
	local lineindices = {
		0, 4, 1, 5,
		2, 6, 3, 7,

		0, 2, 1, 3,
		4, 6, 5, 7,

		0, 1, 2, 3,
		4, 5, 6, 7,
	}

	local rays = {}
	for i=1, #lineindices, 2 do
		local s0, s1 = lineindices[i]+1, lineindices[i+1]+1
		local p0, p1 = math3d.array_index(boxpoints, s0), math3d.array_index(boxpoints, s1)
		rays[#rays+1] = {o=p0, d=math3d.sub(p1, p0)}
	end
	return rays
end

local function frustum_interset_aabb(M, aabb)
	local vertices = {}

	local function check_point_inside_box(points, checkop, insidepoints)
		for i=1, 8 do
			local corner = math3d.array_index(points, i)
			if checkop(corner) then
				insidepoints[#insidepoints+1] = corner
			end
		end
	end

	local frustumpoints	= math3d.frustum_points(M)

	check_point_inside_box(frustumpoints, function (p)
		return math3d.aabb_test_point(aabb, p) >= 0 end,
	vertices)

	--check frustum included aabb
	if #vertices == 8 then
		return math3d.array_vector(vertices)
	end

	local frustumplanesLS	= math3d.frustum_planes(M)
	local aabbpointsLS		= math3d.aabb_points(aabb)
	check_point_inside_box(aabbpointsLS, function (p)
		return math3d.frustum_test_point(frustumplanesLS, p) >= 0 end,
	vertices)

	--frustum interset with aabb or aabb inside frustum
	if #vertices < 8 then
		local function to_results(results)
			if results ~= mc.NULL then
				for i=1, math3d.array_size(results) do
					vertices[#vertices+1] = math3d.array_index(results, i)
				end
			end
		end
		for _, r in ipairs(build_box_rays(frustumpoints)) do
			to_results(math3d.ray_intersect_box(r.o, r.d, aabbpointsLS))
		end

		for _, r in ipairs(build_box_rays(aabbpointsLS)) do
			to_results(math3d.ray_intersect_box(r.o, r.d, frustumpoints))
		end

		-- rays_planes(build_box_rays(frustumpoints), aabbplanesLS, function (pt)
		-- 	if math3d.aabb_test_point(aabb, pt) >= 0 then
		-- 		vertices[#vertices+1] = update_nearfar(pt)
		-- 		intersect_points[#intersect_points+1] = pt
		-- 	end
		-- end)

		-- local frustumplanes = math3d.frustum_planes(M)
		-- rays_planes(build_box_rays(aabbpointsLS), frustumplanes, function (pt)
		-- 	if math3d.frustum_test_point(frustumplanes, pt) >= 0 then
		-- 		vertices[#vertices+1] = update_nearfar(pt)
		-- 		intersect_points[#intersect_points+1] = pt
		-- 	end
		-- end)
	end

	return #vertices > 0 and math3d.array_vector(vertices) or mc.NULL
end

local function mark_camera_changed(e)
	-- this camera should not generate the change tag
	w:extend(e, "scene_changed?out scene_needchange?out camera_changed?out")
	e.camera_changed = true
	e.scene_changed = false
	e.scene_needchange = false
	w:submit(e)
end

local function calc_focus_matrix(M, vertices)
	if mc.NULL == vertices then
		return mc.IDENTITY_MAT
	end
	local aabb = math3d.minmax(vertices, M)
	-- extents = (maxv-minv) * 0.5
	-- center  = (maxv+minv) * 0.5
	local center, extents = math3d.aabb_center_extents(aabb)

	local ex, ey = math3d.index(extents, 1, 2)
	local sx, sy = 1.0/ex, 1.0/ey

	local tx, ty = math3d.index(center, 1, 2)
	-- inverse scale to translation
	tx, ty = sx * tx, sy * ty

	return math3d.matrix(
		sx,  0.0, 0.0, 0.0,
		0.0, sy,  0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		tx,  ty,  0.0, 1.0)
end

local function update_camera(c, Lv, Lp)
	c.viewmat.m		= Lv
	c.projmat.m		= Lp
	c.infprojmat.m	= Lp
	c.viewprojmat.m	= math3d.mul(Lp, Lv)
end

local function update_warp_camera(c, Lv, Lp, Lr, Wv, Wp, vertices)
	c.Lr.m	= Lr
	c.Wv.m	= Wv
	c.Wp.m	= Wp
	c.Wpv.m	= math3d.mul(Wp, Wv)
	c.Wpvl.m= math3d.mul(c.Wpv, Lr)

	c.W.m	= math3d.mul(c.Wpvl, Lp)

	local F = calc_focus_matrix(c.W, vertices)
	c.F.m			= F

	update_camera(c, Lv, math3d.mul(c.F, c.W))
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

local function calc_viewspace_z(n, f, r)
	return n + (f-n) * r
end

local INV_Z<const> = true

local function build_scene_aabb(Lv)
	local mqidx = queuemgr.queue_index "main_queue"
	local PSRLS	= build_PSR(mqidx, Lv)
	local PSCLS	= build_PSC(mqidx, Lv)

	return merge_PSC_and_PSR(PSRLS, PSCLS)
end

function shadow_sys:update_camera_depend()
    local C = w:first "camera_changed"
    if not C then
        return
    end

	local D = w:first "make_shadow directional_light scene:in"
	if not D then
		return 
	end

    C = world:entity(irq.main_camera(), "camera_changed?in")
	if not C.camera_changed then
		return 
	end

	--[[
	the target here is try to find a bounding volume which bound the visible object inode lighting space as tighting as posibile
	we try to do:
		1) find the PSR and PSC in light space. where the PSC near plane is the light view project near plane.
		2) PSRLS in light space actually is the scene aabb for casting shadow, so we use it as scene aabb.
		3) find the view frustum in different layer of csm, and interset with PSRLS to find interset's points(store in vertices).
		4) the vertices only represents the visible object in view frustum, but light frustum visible object may lay outside the volume defined by vertices
			so, we need to generate a bounding aabb by vertices, then make this aabb.min.z = PSCLS.min.z

	build PSRLS as scene aabb --> PSRLS intersert with csm view frustum --> light frustum aabb.min.z = PSCLS.min.z
	]]

    w:extend(C, "scene:in camera:in")
	local lightdirWS = math3d.index(D.scene.worldmat, 3)

	local rightdir, viewdir, posWS = math3d.index(C.scene.worldmat, 1, 3, 4)
	local Lv = math3d.lookto(mc.ZERO_PT, lightdirWS, rightdir)
	local Lw = math3d.inverse_fast(Lv)

	local sceneaabbLS	= build_scene_aabb(Lv)
	local sceneaabbWS	= math3d.aabb_transform(sceneaabbLS, Lw)
	
	local Cv = C.camera.viewmat
	local Lv2Vv 		= math3d.mul(Cv, Lw)

	local useLiSPSM = false
	local Lr
	if useLiSPSM then
		local viewdirLS = math3d.transform(Lv, viewdir, 0)
		Lr = LiSPSM.rotation_matrix(viewdirLS)
	end

	--TODO: hardcode
	local split_ratio = {
		{0.0,  1.0},
		{0.1,  0.25},
		{0.25, 0.5},
		{0.5,  1.0},
	}

	local zn, zf = C.camera.frustum.n, C.camera.frustum.f

	--TODO: need get from setting file
	local nearHit, farHit = 1, 100
	local viewfrustum = {}; for k, v in pairs(C.camera.frustum) do viewfrustum[k] = v end

    for e in w:select "csm:in camera_ref:in queue_name:in" do
        local ce<close> = world:entity(e.camera_ref, "scene:update camera:in")	--update scene.worldmat
        local c = ce.camera
        local csm = e.csm

		local sr	= split_ratio[csm.index]

		viewfrustum.n, viewfrustum.f = calc_viewspace_z(zn, zf, sr[1]), calc_viewspace_z(zn, zf, sr[2])
		local sp 	= math3d.projmat(viewfrustum)
		local Lv2Ndc = math3d.mul(sp, Lv2Vv)
		c.Lv2Ndc = M3D(c.Lv2Ndc, Lv2Ndc)

		local svp = math3d.mul(sp, Lv)
		local verticesLS = frustum_interset_aabb(c.Lv2Ndc, sceneaabbLS)
		local DEBUG_verticesWS = frustum_interset_aabb(svp, sceneaabbWS)

		local intersectaabb = mc.NULL
		if mc.NULL ~= verticesLS then
			intersectaabb = math3d.minmax(verticesLS)
			local minv, maxv = math3d.array_index(intersectaabb, 1), math3d.array_index(intersectaabb, 2)
			
			c.frustum.n, c.frustum.f = math3d.index(minv, 3), math3d.index(maxv, 3)
			c.DEBUG_verticesWS = M3D(c.DEBUG_verticesWS, DEBUG_verticesWS)	--TODO just debug
			c.verticesLS = M3D(c.verticesLS, verticesLS)	--TODO just debug
		end

		local Lp	= math3d.projmat(c.frustum, INV_Z)

		if useLiSPSM then
			local Lrp	= math3d.mul(Lr, Lp)
			local camerainfo = {
				Lv			= Lv,
				Lrp			= Lrp,
				Lrpv		= math3d.mul(Lrp, Lv),
				Cv			= Cv,
				viewdirWS	= viewdir,
				lightdirWS	= lightdirWS,
				cameraposWS	= posWS,
				zn			= zn,
				zf			= zf,
				nearHit		= nearHit,
				farHit		= farHit,
			}
			local Wv, Wp = LiSPSM.warp_matrix(camerainfo, verticesLS)
			update_warp_camera(c, Lv, Lp, Lr, Wv, Wp, verticesLS)
		else
			--local F 		= calc_focus_matrix(Lp, math3d.aabb_points(C.camera.PSCLS))
			local F 		= calc_focus_matrix(Lp, verticesLS)
			local FLp 		= math3d.mul(F, Lp)

			update_camera(c, Lv, FLp)
		end

		ce.scene.worldmat = M3D(ce.scene.worldmat, Lw)
		mark_camera_changed(ce)

		csm_matrices[csm.index].m = math3d.mul(ishadowcfg.crop_matrix(csm.index), c.viewprojmat)
		split_distances_VS[csm.index] = calc_viewspace_z(zn, zf, sr[2])	--TODO: need remove
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



----
local COLORS<const> = {
	{1.0, 0.0, 0.0, 1.0},
	{0.0, 1.0, 0.0, 1.0},
	{0.0, 0.0, 1.0, 1.0},
	{0.0, 0.0, 0.0, 1.0},
	{1.0, 1.0, 0.0, 1.0},
	{1.0, 0.0, 1.0, 1.0},
	{0.0, 1.0, 1.0, 1.0},
	{0.5, 0.5, 0.5, 1.0},
	{0.8, 0.8, 0.1, 1.0},
	{0.1, 0.8, 0.1, 1.0},
	{0.1, 0.5, 1.0, 1.0},
	{0.5, 1.0, 0.5, 1.0},
}

local unique_color, unique_name; do
	local idx = 0
	function unique_color()
		idx = idx % #COLORS
		idx = idx + 1
		return COLORS[idx]
	end

	local nidx = 0
	function unique_name()
		local id = idx + 1
		local n = "debug_entity" .. id
		idx = id
		return n
	end
end

local DEBUG_ENTITIES = {}
local ientity 		= ecs.require "components.entity"
local imesh 		= ecs.require "ant.asset|mesh"
local kbmb 			= world:sub{"keyboard"}

local shadowdebug_sys = ecs.system "shadow_debug_system2"

local function debug_viewid(n, after)
	local viewid = hwi.viewid_get(n)
	if nil == viewid then
		viewid = hwi.viewid_generate(n, after)
	end

	return viewid
end

local DEBUG_view = {
	queue = {
		depth = {
			viewid = debug_viewid("shadowdebug_depth", "pre_depth"),
			queue_name = "shadow_debug_depth_queue",
			queue_eid = nil,
		},
		color = {
			viewid = debug_viewid("shadowdebug", "ssao"),
			queue_name = "shadow_debug_queue",
			queue_eid = nil,
		}
	},
	light = {
		perspective_camera = nil,
	},
	drawereid = nil
}

local function update_visible_state(e)
	w:extend(e, "eid:in")
	if e.eid == DEBUG_view.drawereid then
		return
	end

	local function update_queue(whichqueue, matchqueue)
		if e.visible_state["pre_depth_queue"] then
			local qn = DEBUG_view.queue[whichqueue].queue_name
			ivs.set_state(e, qn, true)
			w:extend(e, "filter_material:update")
			e.filter_material[qn] = e.filter_material[matchqueue]
		end
	end

	update_queue("depth", "pre_depth_queue")
	update_queue("color", "main_queue")
end

function shadowdebug_sys:init_world()
	--make shadow_debug_queue as main_queue alias name, but with different render queue(different render_target)
	queuemgr.register_queue("shadow_debug_depth_queue",	queuemgr.material_index "pre_depth_queue")
	queuemgr.register_queue("shadow_debug_queue", 		queuemgr.material_index "main_queue")
	local vr = irq.view_rect "main_queue"
	local fbw, fbh = vr.h // 2, vr.h // 2
	local depth_rbidx = fbmgr.create_rb{
		format="D32F", w=fbw, h=fbh, layers=1,
		flags = sampler {
			RT = "RT_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		},
	}

	local depthfbidx = fbmgr.create{rbidx=depth_rbidx}

	local fbidx = fbmgr.create(
					{rbidx = fbmgr.create_rb{
						format = "RGBA16F", w=fbw, h=fbh, layers=1,
						flags=sampler{
							RT="RT_ON",
							MIN="LINEAR",
							MAG="LINEAR",
							U="CLAMP",
							V="CLAMP",
						}
					}},
					{rbidx = depth_rbidx}
				)

	DEBUG_view.queue.depth.queue_eid = world:create_entity{
		policy = {"ant.render|render_queue"},
		data = {
			render_target = {
				viewid = DEBUG_view.queue.depth.viewid,
				view_rect = {x=0, y=0, w=fbw, h=fbh},
				clear_state = {
					clear = "D",
					depth = 0,
				},
				fb_idx = depthfbidx,
			},
			visible = true,
			camera_ref = irq.camera "csm1_queue",
			queue_name = "shadow_debug_depth_queue",
		}
	}
	
	DEBUG_view.queue.color.queue_eid = world:create_entity{
		policy = {
			"ant.render|render_queue",
		},
		data = {
			render_target = {
				viewid = DEBUG_view.queue.color.viewid,
				view_rect = {x=0, y=0, w=fbw, h=fbh},
				clear_state = {
					clear = "C",
					color = 0,
				},
				fb_idx = fbidx,
			},
			visible = true,
			camera_ref = irq.camera "csm1_queue",
			queue_name = "shadow_debug_queue",
		},
	}

	DEBUG_view.drawereid = world:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			simplemesh = imesh.init_mesh(ientity.quad_mesh(mu.rect2ndc({x=0, y=0, w=fbw, h=fbh}, irq.view_rect "main_queue")), true),
			material = "/pkg/ant.resources/materials/texquad.material",
			visible_state = "main_queue",
			scene = {},
			render_layer = "translucent",
			on_ready = function (e)
				imaterial.set_property(e, "s_tex", fbmgr.get_rb(fbidx, 1).handle)
			end,
		}
	}

	for e in w:select "render_object visible_state:in" do
		update_visible_state(e)
	end
end

function shadowdebug_sys:entity_init()
	for e in w:select "INIT render_object visible_state:in" do
		update_visible_state(e)
	end
end

local function draw_lines(lines)
	return world:create_entity{
		policy = {"ant.render|simplerender"},
		data = {
			simplemesh = {
				vb = {
					start = 0, num = #lines,
					handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(table.concat(lines)), layoutmgr.get "p3|c40".handle),
					owned = true,
				},
			},
			material = "/pkg/ant.resources/materials/line.material",
			scene = {},
			visible_state = "main_view",
			owned_mesh_buffer = true,
		}
	}
end

function shadowdebug_sys:data_changed()
	for _, key, press in kbmb:unpack() do
		if key == "B" and press == 0 then
			for k, v in pairs(DEBUG_ENTITIES) do
				w:remove(v)
			end

			local function add_entity(points, c, n)
				local eid = ientity.create_frustum_entity(points, c or unique_color())
				n = n or unique_name()
				DEBUG_ENTITIES[n] = eid
				return eid
			end

			local function transform_points(points, M)
				local np = {}
				for i=1, math3d.array_size(points) do
					np[i] = math3d.transform(M, math3d.array_index(points, i), 1)
				end

				return math3d.array_vector(np)
			end

			local C = world:entity(irq.main_camera(), "camera:in").camera
			for e in w:select "csm:in camera_ref:in" do
				local ce = world:entity(e.camera_ref, "camera:in scene:in")
				local Lv = ce.camera.viewmat
				local L2W = math3d.inverse_fast(Lv)
				local aabbpoints = transform_points(math3d.aabb_points(C.PSRLS), L2W)
				add_entity(aabbpoints,	{0.0, 0.0, 1.0, 1.0})

				if ce.camera.vertices then
					local aabb = math3d.minmax(ce.camera.vertices, L2W)
					add_entity(math3d.aabb_points(aabb),	{1.0, 1.0, 0.0, 1.0})
				end

				add_entity(transform_points(math3d.frustum_points(ce.camera.Lv2Ndc), L2W),	{1.0, 0.0, 0.0, 1.0})
			end
		elseif key == 'C' and press == 0 then

		end
	end
end
