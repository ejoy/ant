local ecs 	= ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
local sm = ecs.system "shadow_system"
if not ENABLE_SHADOW then
	return
end

local assetmgr	= import_package "ant.asset"

local queuemgr	= ecs.require "queue_mgr"

local hwi		= import_package "ant.hwi"
--local mu		= mathpkg.util
local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local R         = world:clibs "render.render_material"
local icamera	= ecs.require "ant.camera|camera"
local ishadow	= ecs.require "ant.render|shadow.shadowcfg"
local imaterial = ecs.require "ant.asset|material"
local iom		= ecs.require "ant.objcontroller|obj_motion"

local RM        = ecs.require "ant.material|material"
local fbmgr		= require "framebuffer_mgr"
local INV_Z<const> = true
local csm_matrices			= {math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT), math3d.ref(mc.IDENTITY_MAT)}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))

local function commit_csm_matrices_attribs()
	imaterial.system_attrib_update("u_csm_matrix",			math3d.array_matrix(csm_matrices))
	imaterial.system_attrib_update("u_csm_split_distances",	split_distances_VS)
end

local function get_intersected_aabb()
	local sbe = w:first "shadow_bounding:in"
	if sbe then
		local scene_aabb, camera_aabb = sbe.shadow_bounding.scene_aabb, sbe.shadow_bounding.camera_aabb
		return math3d.aabb_intersection(scene_aabb, camera_aabb)
	else
		return math3d.aabb()
	end
end

-- bgfx method
local function update_csm_frustum(lightdir, shadowmap_size, csm_frustum, shadow_ce, intersected_aabb)

	local function update_shadow_camera_srt()
		iom.set_rotation(shadow_ce, math3d.torotation(lightdir))
		math3d.unmark(shadow_ce.scene.worldmat)
		shadow_ce.scene.worldmat = math3d.marked_matrix(shadow_ce.scene)
	end

	local function update_shadow_camera_matrix(light_view, light_proj)
	   local camera = shadow_ce.camera
	   camera.viewmat.m = light_view
	   camera.projmat.m = light_proj
	   camera.infprojmat.m = light_proj
	   camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
   
	   -- this camera should not generate the change tag
	   w:extend(shadow_ce, "scene_changed?out scene_needchange?out camera_changed?out")
	   shadow_ce.camera_changed = true
	   shadow_ce.scene_changed = false
	   shadow_ce.scene_needchange = false
	   w:submit(shadow_ce)
	end

	local function get_light_view_proj_matrix()
		local light_world = shadow_ce.scene.worldmat
		local light_view = math3d.inverse(light_world)
		local aabb_points = math3d.aabb_points(intersected_aabb)
		local light_frustum_minmax = math3d.minmax(aabb_points, light_view)
		local frustum_ortho = {
			l = 1, r = -1,
			t = 1, b = -1,
			n = -csm_frustum.f, f = csm_frustum.f,
			ortho = true,
		}
		local ortho_proj = math3d.projmat(frustum_ortho, INV_Z)
		local min_proj, max_proj = math3d.transformH(ortho_proj, math3d.array_index(light_frustum_minmax, 1)), math3d.transformH(ortho_proj, math3d.array_index(light_frustum_minmax, 2))
		local minp, maxp = math3d.tovalue(min_proj), math3d.tovalue(max_proj)
		local scalex, scaley = 2 / (maxp[1] - minp[1]), 2 / (maxp[2] - minp[2])
		local quantizer = 64
		scalex, scaley = 64 / math.ceil(quantizer / scalex),  64 / math.ceil(quantizer / scaley)
		local offsetx, offsety = 0.5 * (maxp[1] + minp[1]) * scalex, 0.5 * (maxp[2] + minp[2]) * scaley
		local half_size = shadowmap_size * 0.5
		offsetx, offsety = math.ceil(offsetx * half_size) / half_size, math.ceil(offsety * half_size) / half_size
		local crop = math3d.matrix{
			scalex, 0, 0, 0,
			0, scaley, 0, 0,
			0, 0, 1, 0,
			-offsetx, -offsety, 0, 1
		}
		ortho_proj = math3d.mul(crop, ortho_proj)
		return light_view, ortho_proj
	end

	update_shadow_camera_srt()
	local light_view, light_proj = get_light_view_proj_matrix()
	update_shadow_camera_matrix(light_view, light_proj)
end

local function calc_csm_matrix_attrib(csmidx, vp)
	return math3d.mul(ishadow.crop_matrix(csmidx), vp)
end

local function update_shadow_frustum(dl, ce, mc_scene_changed)
	local lightdir = iom.get_direction(dl)
	local shadow_setting = ishadow.setting()
	local csm_frustums = ishadow.calc_split_frustums(ce.camera.frustum)
	local intersected_aabb = get_intersected_aabb()
	local shadow_camera_changed = false
	for qe in w:select "csm:in camera_ref:in" do
		local csm = qe.csm
		local csm_frustum = csm_frustums[csm.index]
		local shadow_ce = world:entity(qe.camera_ref, "camera:in scene:in camera_changed?in")
		if mc_scene_changed or shadow_ce.camera_changed then
			shadow_camera_changed = true
			update_csm_frustum(lightdir, shadow_setting.shadowmap_size, csm_frustum, shadow_ce, intersected_aabb, ce.camera.viewmat)
			csm_matrices[csm.index].m = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
			split_distances_VS[csm.index] = csm_frustum.f
		end
	end
	return shadow_camera_changed
end

local function update_shadow_attribs(dl, ce, mc_scene_changed)
	local shadow_camera_changed = update_shadow_frustum(dl, ce, mc_scene_changed)
	if shadow_camera_changed or mc_scene_changed then
		commit_csm_matrices_attribs()
	end
end

function sm:update_camera_depend()
	local dl = w:first "csm_directional_light scene_changed?in scene:in"
	if dl then
		local mq = w:first "main_queue camera_ref:in"
		local ce <close> = world:entity(mq.camera_ref, "camera_changed?in camera:in scene:in")
		local mc_scene_changed = dl.scene_changed or ce.camera_changed
		update_shadow_attribs(dl, ce, mc_scene_changed)
	end
end

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
			name = csmname,
			camera_depend = true,
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
		},
	}
end

local shadow_material
local gpu_skinning_material
local di_shadow_material
function sm:init()
	local fbidx = ishadow.fb_index()
	local s = ishadow.shadowmap_size()
	create_clear_shadowmap_queue(fbidx)
	shadow_material 			= assetmgr.resource "/pkg/ant.resources/materials/predepth.material"
	gpu_skinning_material 		= assetmgr.resource "/pkg/ant.resources/materials/predepth_skin.material"
	di_shadow_material 			= assetmgr.resource "/pkg/ant.resources/materials/predepth_di.material"
	for ii=1, ishadow.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx)
	end
end

local function set_csm_visible(enable)
	for v in w:select "csm visible?out" do
		v.visible = enable
	end
end

function sm:entity_init()
	for e in w:select "INIT make_shadow directional_light light:in csm_directional_light?update" do
		if w:count "csm_directional_light" > 0 then
			log.warn("Multi directional light for csm shaodw")
		end
		e.csm_directional_light = true
		set_csm_visible(true)
	end
end

function sm:entity_remove()
	for _ in w:select "REMOVED csm_directional_light" do
		set_csm_visible(false)
	end
end

function sm:init_world()
	imaterial.system_attrib_update("s_shadowmap", fbmgr.get_rb(ishadow.fb_index(), 1).handle)
	imaterial.system_attrib_update("u_shadow_param1", ishadow.shadow_param())
	imaterial.system_attrib_update("u_shadow_param2", ishadow.shadow_param2())
end

local CLEAR_SM_viewid<const> = hwi.viewid_get "csm_fb"
function sm:render_preprocess()
	bgfx.touch(CLEAR_SM_viewid)
end

local function which_material(e, matres)
	if matres.fx.depth then
		return matres
	end
    w:extend(e, "skinning?in draw_indirect?in")
	if e.draw_indirect then
		return di_shadow_material
	else
		return e.skinning and gpu_skinning_material or shadow_material
	end
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

function sm:follow_scene_update()
	for e in w:select "visible_state_changed visible_state:in material:in cast_shadow?out" do
		local castshadow
		if e.visible_state["cast_shadow"] then
			local mt = assetmgr.resource(e.material)
			castshadow = mt.fx.setting.cast_shadow == "on"
		end

		e.cast_shadow		= castshadow
	end
end

function sm:update_filter()
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