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
	imaterial.system_attrib_update("u_shadow_param1", isc.shadow_param())
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

local function update_shadow_matrices(si, li, c)
	local sp = math3d.projmat(c.viewfrustum)
	local Lv2Ndc = math3d.mul(sp, li.Lv2Cv)

	local verticesLS = math3d.frustum_aabb_intersect_points(Lv2Ndc, si.sceneaabbLS)

	local Lp
	if mc.NULL ~= verticesLS then
		local intersectaabb = math3d.minmax(verticesLS)
		c.frustum.n, c.frustum.f = mu.aabb_minmax_index(intersectaabb, 3)

		Lp = math3d.projmat(c.frustum, INV_Z)
		if useLiSPSM then
			li.Lp = Lp
			local Wv, Wp = LiSPSM.warp_matrix(si, li, verticesLS)
			Lp = math3d.mul(math3d.mul(math3d.mul(Wp, Wv), li.Lr), Lp)
		end

		local F = isc.calc_focus_matrix(math3d.minmax(verticesLS, Lp))
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

	local SB = w:first "shadow_bounding:in".shadow_bounding
	local si = SB.scene_info
	
	local li = init_light_info(C, D)
	si.sceneaabbLS = build_sceneaabbLS(si, li)

	local CF = C.camera.frustum
	si.view_near, si.view_far = CF.n, CF.f
	local zn, zf = assert(si.zn), assert(si.zf)
	--split bounding zn, zf
	local csmfrustums = isc.split_viewfrustum(zn, zf, CF)

    for e in w:select "csm:in camera_ref:in queue_name:in" do
        local ce<close> = world:entity(e.camera_ref, "scene:update camera:in")	--update scene.worldmat
		ce.scene.worldmat = M3D(ce.scene.worldmat, li.Lw)

        local c = ce.camera
        local csm = e.csm
		c.viewfrustum = csmfrustums[csm.index]
		update_shadow_matrices(si, li, c)
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
