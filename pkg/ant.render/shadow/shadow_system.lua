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
	local camera_ref = icamera.create({
			updir 	= mc.YAXIS,
			viewdir = mc.ZAXIS,
			eyepos 	= mc.ZERO_PT,
			frustum = {
				l = -1, r = 1, t = -1, b = 1,
				n = 1, f = 100, ortho = true,
			},
			name = csmname
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
			c.FinalMat=	math3d.ref()
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

local function merge_visible_bounding(M, aabb, e, queue_index)
	local ro = e.render_object
	if Q.check(ro.visible_idx, queue_index) and mc.NULL ~= e.bounding.scene_aabb then
		if M then
			aabb = math3d.aabb_merge(aabb, math3d.aabb_transform(M, e.bounding.scene_aabb))
		else
			aabb = math3d.aabb_merge(aabb, e.bounding.scene_aabb)
		end
	end

	return aabb
end

local function build_aabb(queue_index, M, tag)
	local aabb = math3d.aabb()
	for e in w:select(("%s render_object:in bounding:in"):format(tag)) do
		aabb = merge_visible_bounding(M, aabb, e, queue_index)
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
	local aabb = math3d.aabb_merge(PSC, PSR)
	local minv, maxv = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
	local PSC_minz = math3d.index(math3d.array_index(PSC, 1), 3)
	local PSR_maxz = math3d.index(math3d.array_index(PSR, 2), 3)
	--because PSR_minz/PSC_maxz is no meanning, caster is far than receive, it's shadow can not be test by any visible object
	minv = math3d.set_index(minv, 3, PSC_minz)
	maxv = math3d.set_index(maxv, 3, PSR_maxz)
	return math3d.aabb(minv, maxv)
end

local function frustum_points(M, n, f)
	return {
		math3d.transform(M, math3d.vector(-1.0,-1.0, n, 1.0), 1),	-- 1
		math3d.transform(M, math3d.vector(-1.0, 1.0, n, 1.0), 1),	-- 2
		math3d.transform(M, math3d.vector( 1.0,-1.0, n, 1.0), 1),	-- 3
		math3d.transform(M, math3d.vector( 1.0, 1.0, n, 1.0), 1),	-- 4
		math3d.transform(M, math3d.vector(-1.0,-1.0, f, 1.0), 1),	-- 5
		math3d.transform(M, math3d.vector(-1.0, 1.0, f, 1.0), 1),	-- 6
		math3d.transform(M, math3d.vector( 1.0 -1.0, f, 1.0), 1),	-- 7
		math3d.transform(M, math3d.vector( 1.0, 1.0, f, 1.0), 1),	-- 8
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

assert(#BOX_TRIANGLES_INDICES == 6*2)

local BOX_SEGMENT_INDICES<const> = {
	{1, 2}, {2, 3}, {3, 4}, {4, 1},
	{5, 6}, {6, 7}, {7, 8}, {8, 5},

	{1, 5}, {2, 6}, {3, 7}, {4, 8},
}

assert(#BOX_SEGMENT_INDICES == 4*3)

local function frustum_interset_aabb(M, aabbLS, nearCS, farCS)
	local nearLS, farLS = math.maxinteger, -math.maxinteger

	local function update_nearfar(p)
		local z = math3d.index(p, 3)
		nearLS = math.min(nearLS, z)
		farLS = math.max(farLS, z)
		return p
	end

	local cornersLS = frustum_points(M, nearCS, farCS)
	local verticesLS = {}
	for _, corner in ipairs(cornersLS) do
		if math3d.aabb_test_point(aabbLS, corner) >= 0 then
			verticesLS[#verticesLS+1] = update_nearfar(corner)
		end
	end
	local aabbpoints = math3d.aabb_points(aabbLS)
	for _, l in ipairs(BOX_SEGMENT_INDICES) do
		local s0, s1 = aabbpoints[l[1]], aabbpoints[l[2]]
		for _, t in ipairs(BOX_TRIANGLES_INDICES) do
			local p = mu.segment_triangle(s0, s1, cornersLS[t[1]], cornersLS[t[2]], cornersLS[t[3]])
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
	local aabb = math3d.aabb()
	for _, v in ipairs(verticesLS) do
		local p = math3d.transformH(M, v)
		aabb = math3d.aabb_append(aabb, p)
	end

	-- extents = maxv - minv
	-- center = (maxv+minv) * 0.5
	local center, extents = math3d.aabb_center_extents(aabb)

	local ex, ey = math3d.index(extents, 1, 2)
	local sx, sy = 2.0/ex, 2.0/ey

	local tx, ty = math3d.index(center, 1, 2)
	-- inverse scale to translation
	tx, ty = -sx * tx, -sy * ty

	return math3d.matrix(
		sx,  0.0, 0.0, 0.0,
		0.0, sy,  0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		tx,  ty,  0.0, 1.0)
end

local function update_camera(c, Lv, Lp, Lr, Wv, Wp, verticesLS)
	c.viewmat.m		= Lv
	c.projmat.m		= Lp
	c.viewprojmat.m	= math3d.mul(Lv, Lp)

	c.Lr.m	= Lr
	c.Wv.m	= Wv
	c.Wp.m	= Wp
	c.Wpv.m	= math3d.mul(Wp, Wv)
	c.Wpvl.m= math3d.mul(c.Wpv, Lr)
	c.W.m	= math3d.mul(c.Wpvl, c.viewprojmat)

	local F = calc_focus_matrix(c.W, verticesLS)
	c.F.m		= F
	c.FinalMat.m= math3d.mul(c.F, c.W)
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

local function M3D(o, n)
	if o then
		math3d.unmark(o)
	end
	return math3d.mark(n)
end

function shadow_sys:refine_camera()
    local C = w:first "camera_changed"
    if not C then
        return
    end

	local D = w:first "make_shadow directional_light scene:in"
	if not D then
		return 
	end

    w:extend(C, "eid:in")
    if C.eid ~= irq.main_camera() then
        return 
    end

    w:extend(C, "scene:in camera:in")
	local lightdirWS = math3d.index(D.scene.worldmat, 3)

	local rightdir, viewdir, posWS = math3d.index(C.scene.worldmat, 1, 3, 4)
	local Lv = math3d.lookat(lightdirWS, mc.ZERO_PT, rightdir)

	local main_queueidx = queuemgr.queue_index "main_queue"
	C.camera.PSR 	= M3D(C.camera.PSR, 	build_PSR(main_queueidx))
	C.camera.PSC	= M3D(C.camera.PSC, 	build_PSC(main_queueidx))

	C.camera.PSRLS	= M3D(C.camera.PSRLS, 	build_PSR(main_queueidx, Lv))
	C.camera.PSCLS	= M3D(C.camera.PSCLS, 	build_PSC(main_queueidx, Lv))

	local sceneaabbLS	= merge_PSC_and_PSR(C.camera.PSCLS, C.camera.PSRLS)
	C.camera.sceneaabbLS= M3D(C.camera.sceneaabbLS, sceneaabbLS)
	C.camera.Lv			= M3D(C.camera.Lv, Lv)

	local Ndc2Lv = math3d.mul(Lv, math3d.inverse(C.camera.viewprojmat))

	local useLiSPSM = false
	local Lr
	if useLiSPSM then
		local viewdirLS = math3d.transform(Lv, viewdir, 0)
		Lr = LiSPSM.rotation_matrix(viewdirLS)
	end

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
        local csm = e.csm

		local sr	= split_ratio[csm.index]
		local verticesLS, nearLS, farLS	= frustum_interset_aabb(Ndc2Lv, sceneaabbLS, sr[1], sr[2])

		local Lp	= math3d.projmat{l=-1, r=1, t=1, b=-1, n=nearLS, f=farLS, ortho=true}
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
			update_camera(c, Lv, Lp, Lr, Wv, Wp, verticesLS)
		else
			c.viewmat.m = Lv
			c.projmat.m = Lp
			local vp = math3d.mul(Lp, Lv)
			
			local F = calc_focus_matrix(Lp, verticesLS)
			c.viewprojmat.m = math3d.mul(F, vp)
			c.FinalMat.m = c.viewprojmat
		end
		mark_camera_changed(ce)

		csm_matrices[csm.index].m = math3d.mul(ishadowcfg.crop_matrix(csm.index), c.FinalMat)
		split_distances_VS[csm.index] = zn + (zf-zn) * (sr[2] - sr[1])	--TODO: need remove
    end
end

local function which_material(e, matres)
	if matres.fx.depth then
		return matres
	end
    w:extend(e, "animation?in")
    return e.animation and gpu_skinning_material or shadow_material
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
		local receiveshadow = mt.fx.setting.receive_shadow == "on"

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
				castshadow = true
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

local unique_color; do
	local idx = 0
	function unique_color()
		idx = idx % #COLORS
		idx = idx + 1
		return COLORS[idx]
	end
end

local DEBUG_ENTITIES = {}
local ientity 		= ecs.require "components.entity"
local imesh 		= ecs.require "ant.asset|mesh"
local kbmb 			= world:sub{"keyboard"}

local shadowdebug_sys = ecs.system "shadow_debug_system2"

local DEBUG_view = {
	queue = {
		depth = {
			viewid = hwi.viewid_generate("shadowdebug_depth", "pre_depth"),
			queue_name = "shadow_debug_depth_queue",
			queue_eid = nil,
		},
		color = {
			viewid = hwi.viewid_generate("shadowdebug", "ssao"),
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
	local fbw, fbh = 512, 512
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

	-- if w:first "INIT csm1_queue" then
	-- 	local qe = w:first "csm1_queue camera_ref:in"
	-- 	local sddq<close> = world:entity(shadowdebug_depthqueue)
	-- 	local sdq<close> = world:entity(shadowdebug_queue)
	-- 	irq.set_camera(sddq, qe.camera_ref)
	-- 	irq.set_camera(sdq, qe.camera_ref)
	-- end
end

function shadowdebug_sys:data_changed()
	for _, key, press in kbmb:unpack() do
		if key == "B" and press == 0 then
			for k, v in pairs(DEBUG_ENTITIES) do
				w:remove(v)
			end

			local frustums = {}
			local function add_frustum(n, m, c)
				frustums[#frustums+1] = n
				frustums[n] = {m = m, c = c or unique_color()}
			end
			local C = world:entity(irq.main_camera(), "camera:in").camera
			-- add_frustum("camera_viewprojmat", C.viewprojmat)

			-- do
			-- 	for e in w:select "csm:in camera_ref:in" do
			-- 		local ce = world:entity(e.camera_ref, "camera:in scene:in")
			-- 		local prefixname = "csm" .. e.csm.index
			-- 		add_frustum(prefixname .. "_viewprojtmat", 	ce.camera.viewprojmat)
			-- 		add_frustum(prefixname .. "_Lrpv", 			math3d.mul(ce.camera.Lr, ce.camera.viewprojmat))
			-- 		add_frustum(prefixname .. "_W", 			ce.camera.W)
			-- 		add_frustum(prefixname .. "_FinalMat", 		ce.camera.FinalMat)
			-- 	end
			-- end

			-- for _, n in ipairs(frustums) do
			-- 	local f = frustums[n]
			-- 	DEBUG_ENTITIES[n] = ientity.create_frustum_entity(math3d.frustum_points(f.m), f.c)
			-- end

			local function aabb_points(aabb, M)
				local points = math3d.aabb_points(aabb)
				if M then
					for i=1, #points do
						points[i] = math3d.transform(M, points[i], 1)
					end
				end
				return points
			end
			local L2W = math3d.inverse(C.Lv)
			--DEBUG_ENTITIES["PSR"]   = ientity.create_frustum_entity(math3d.array_vector(aabb_points(C.PSR)),  		{1.0, 0.0, 0.0, 1.0})
			--DEBUG_ENTITIES["PSC"]   = ientity.create_frustum_entity(math3d.array_vector(aabb_points(C.PSC)),  		{0.0, 1.0, 0.0, 1.0})
			--DEBUG_ENTITIES["PSRLS"] = ientity.create_frustum_entity(math3d.array_vector(aabb_points(C.PSRLS, L2W)),{1.0, 0.1, 0.1, 1.0})
			--DEBUG_ENTITIES["PSCLS"] = ientity.create_frustum_entity(math3d.array_vector(aabb_points(C.PSCLS, L2W)),{0.1, 1.0, 0.1, 1.0})

			-- local L2W = math3d.inverse(C.Lv)
			DEBUG_ENTITIES["sceneaabbLS"] = ientity.create_frustum_entity(math3d.array_vector(math3d.aabb_points(C.sceneaabbLS, L2W)),{1.0, 0.0, 0.0, 1.0})
			DEBUG_ENTITIES["sceneaabb"] = ientity.create_frustum_entity(math3d.array_vector(math3d.aabb_points(C.sceneaabb)),{0.0, 1.0, 0.0, 1.0})
		elseif key == 'C' and press == 0 then

		end
	end
end
