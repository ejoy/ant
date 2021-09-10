-- TODO: should move to scene package

local ecs = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"

local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"
local icamera	= world:interface "ant.camera|camera"
local ishadow	= world:interface "ant.render|ishadow"
local irender	= world:interface "ant.render|irender"
local iom		= world:interface "ant.objcontroller|obj_motion"
local ies		= world:interface "ant.scene|ientity_state"
-- local function create_crop_matrix(shadow)
-- 	local view_camera = world.main_queue_camera(world)

-- 	local csm = shadow.csm
-- 	local csmindex = csm.index
-- 	local shadowcamera = world[shadow.camera_ref].camera
-- 	local shadow_viewmatrix = mu.view_proj(shadowcamera)

-- 	local bb_LS = get_frustum_points(view_camera, view_camera.frustum, shadow_viewmatrix, shadow.csm.split_ratios)
-- 	local aabb = bb_LS:get "aabb"
-- 	local min, max = aabb.min, aabb.max

-- 	local proj = math3d.projmat(shadowcamera.frustum)
-- 	local minproj, maxproj = math3d.transformH(proj, min) math3d.transformH(proj, max)

-- 	local scalex, scaley = math3d.mul(2, math3d.reciprocal(math3d.sub(maxproj, minproj)))
-- 	if csm.stabilize then
-- 		local quantizer = shadow.shadowmap_size
-- 		scalex = quantizer / math.ceil(quantizer / scalex);
-- 		scaley = quantizer / math.ceil(quantizer / scaley);
-- 	end

-- 	local function calc_offset(a, b, scale)
-- 		return (a + b) * 0.5 * scale
-- 	end

-- 	local offsetx, offsety = 
-- 		calc_offset(maxproj[1], minproj[1], scalex), 
-- 		calc_offset(maxproj[2], minproj[2], scaley)

-- 	if csm.stabilize then
-- 		local half_size = shadow.shadowmap_size * 0.5;
-- 		offsetx = math.ceil(offsetx * half_size) / half_size;
-- 		offsety = math.ceil(offsety * half_size) / half_size;
-- 	end
	
-- 	return {
-- 		scalex, 0, 0, 0,
-- 		0, scaley, 0, 0,
-- 		0, 0, 1, 0,
-- 		offsetx, offsety, 0, 1,
-- 	}
-- end

local function keep_shadowmap_move_one_texel(minextent, maxextent, shadowmap_size)
	local texsize = 1 / shadowmap_size

	local unit_pretexel = math3d.mul(math3d.sub(maxextent, minextent), texsize)
	local invunit_pretexel = math3d.reciprocal(unit_pretexel)

	local function limit_move_in_one_texel(value)
		-- value /= unit_pretexel;
		-- value = floor( value );
		-- value *= unit_pretexel;
		return math3d.tovalue(
			math3d.mul(math3d.floor(math3d.mul(value, invunit_pretexel)), unit_pretexel))
	end

	local newmin = limit_move_in_one_texel(minextent)
	local newmax = limit_move_in_one_texel(maxextent)
	
	minextent[1], minextent[2] = newmin[1], newmin[2]
	maxextent[1], maxextent[2] = newmax[1], newmax[2]
end

local function light_matrix(center_WS, lightdir)
	if math3d.isequal(mc.ZAXIS, lightdir) then
		return math3d.set_columns(mc.IDENTITY_MAT, mc.XAXIS, mc.YAXIS, mc.ZAXIS, center_WS)
	end

	if math3d.isequal(mc.NZAXIS, lightdir) then
		return math3d.set_columns(mc.IDENTITY_MAT, mc.XAXIS, mc.NYAXIS, mc.NZAXIS, center_WS)
	end
	local yaxis = math3d.cross(mc.ZAXIS, lightdir)
	local xaxis = math3d.cross(yaxis, lightdir)

	return math3d.set_columns(mc.IDENTITY_MAT, xaxis, yaxis, lightdir, center_WS)
end

local function update_camera_matrices(rc)
	rc.viewmat	= math3d.inverse(math3d.matrix(rc.srt))
	rc.worldmat	= rc.srt
	rc.projmat	= math3d.projmat(rc.frustum)
	rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
end

local function calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, camera_rc)
	local center_WS = math3d.points_center(corners_WS)
	local min_extent, max_extent

	camera_rc.srt.id = light_matrix(center_WS, lightdir)

	if stabilize then
		local radius = math3d.points_radius(corners_WS, center_WS)
		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
		keep_shadowmap_move_one_texel(min_extent, max_extent, shadowmap_size)
	else
		local minv, maxv = math3d.minmax(corners_WS, camera_rc.viewmat)
		min_extent, max_extent = math3d.tovalue(minv), math3d.tovalue(maxv)
	end

	camera_rc.frustum = {
		ortho=true,
		l = min_extent[1], r = max_extent[1],
		b = min_extent[2], t = max_extent[2],
		n = min_extent[3], f = max_extent[3],
	}

	update_camera_matrices(camera_rc)


	-- do
	-- 	local ident_projmat = math3d.projmat{
	-- 		ortho=true,
	-- 		l=-1, r=1, b=-1, t=1, n=-100, f=100,
	-- 	}

	-- 	local minv, maxv = math3d.minmax(corners_WS, camera_rc.viewmat)
	-- 	local minv_proj, maxv_proj = math3d.transformH(ident_projmat, minv, 1), math3d.transformH(ident_projmat, maxv, 1)
	-- 	-- scale = 2 / (maxv_proj-minv_proj)
	-- 	local scale = math3d.mul(2, math3d.reciprocal(math3d.sub(maxv_proj, minv_proj)))
	-- 	-- offset = 0.5 * (minv_proj+maxv_proj) * scale
	-- 	local offset = math3d.mul(scale, math3d.mul(0.5, math3d.add(minv_proj, maxv_proj)))
	-- 	local scalex, scaley = math3d.index(scale, 1, 2)
	-- 	local offsetx, offsety = math3d.index(offset, 1, 2)
	-- 	local lightproj = math3d.mul(math3d.matrix(
	-- 	scalex, 0.0, 	0.0, 0.0,
	-- 	0.0,	scaley,	0.0, 0.0,
	-- 	0.0,	0.0,	1.0, 0.0,
	-- 	offsetx,offsety,0.0, 1.0
	-- 	), ident_projmat)

	-- 	camera_rc.projmat = lightproj
	-- 	camera_rc.viewprojmat = math3d.mul(camera_rc.projmat, camera_rc.viewmat)
	-- end
end

local function calc_shadow_camera(camera, frustum, lightdir, shadowmap_size, stabilize, sc_eid)
	local vp = math3d.mul(math3d.projmat(frustum), camera.viewmat)

	local corners_WS = math3d.frustum_points(vp)
	local camera_rc = icamera.find_camera(sc_eid)
	calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, camera_rc)
end

local function update_shadow_camera(dl_eid, camera)
	local lightdir = iom.get_direction(dl_eid)
	local setting = ishadow.setting()
	local viewfrustum = camera.frustum
	local csmfrustums = ishadow.calc_split_frustums(viewfrustum)

	for qe in w:select "csm_queue camera_ref:in csm:in" do
		local csm = qe.csm
		local cf = csmfrustums[csm.index]
		calc_shadow_camera(camera, cf, lightdir, setting.shadowmap_size, setting.stabilize, qe.camera_ref)
		csm.split_distance_VS = cf.f - viewfrustum.n
	end
end

local sm = ecs.system "shadow_system"

local function create_csm_entity(index, vr, fbidx, depth_type)
	local csmname = "csm" .. index
	local queuename = "csm_queue" .. index
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

	w:register {name = queuename}
	world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|cull",
			"ant.render|csm_queue",
			"ant.general|name",
		},
		data = {
			csm = {
				index = index,
				split_distance_VS = 0,
			},
			camera_ref = camera_ref,
			render_target = {
				viewid = viewidmgr.get(csmname),
				view_mode = "s",
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				clear_state = {
					color = 0xffffffff,
					depth = 1,
					stencil = 0,
					clear = depth_type == "linear" and "CD" or "D",
				},
				fb_idx = fbidx,
			},
			primitive_filter = {
				filter_type = "cast_shadow",
				"opacity",
			},
			cull_tag = {},
			visible = false,
			queue_name = queuename,
			csm_queue = true,
			name = "csm" .. index,
			need_touch = true,
			shadow_render_queue = {},
		},
	}
end

local shadow_material
local gpu_skinning_material
local imaterial = world:interface "ant.asset|imaterial"
function sm:init()
	local fbidx = ishadow.fb_index()
	local s, dt = ishadow.shadowmap_size(), ishadow.depth_type()

	local originmatrial = "/pkg/ant.resources/materials/depth.material"
	shadow_material = imaterial.load(originmatrial, {depth_type=dt})
	gpu_skinning_material = imaterial.load(originmatrial, {depth_type=dt, skinning="GPU"})
	for ii=1, ishadow.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx, dt)
	end
end

local viewcamera_changed_mb
local viewcamera_frustum_mb

function sm:entity_init()
	for e in w:select "INIT main_queue camera_ref:in" do
		local camera_ref = e.camera_ref
		viewcamera_frustum_mb = world:sub{"component_changed", "frusutm", camera_ref}
		viewcamera_changed_mb = world:sub{"component_changed", "viewcamera", camera_ref}
		world:pub{"component_changed", "viewcamera", camera_ref}	--init shadowmap
	end
end

local dl_eid
local create_light_mb = world:sub{"component_register", "make_shadow"}
local remove_light

local function set_csm_visible(enable)
	for v in w:select "csm_queue visible?out" do
		v.visible = enable
	end
end

local function find_directional_light(eid)
	local e = world[eid]
	if e and e.light_type == "directional" and e.make_shadow then
		if dl_eid then
			log.warn("already has directional light for making shadow")
		else
			dl_eid = eid
		end

		return dl_eid
	end
end

function sm:data_changed()
	for msg in create_light_mb:each() do
		local eid = msg[3]
		if find_directional_light(eid) then
			remove_light = eid
			set_csm_visible(true)
		end
	end

	if remove_light then
		for _, eid in world:each "removed" do
			if remove_light == eid then
				assert(eid == dl_eid)
				dl_eid = nil
				set_csm_visible(false)
			end
		end
	end

	for v in w:select "scene_changed main_queue eid:in" do
		world:pub{"component_changed", "viewcamera", v.eid}
	end

	for msg in viewcamera_frustum_mb:each() do
		world:pub{"component_changed", "viewcamera", msg[3]}
	end
end

local function find_main_camera()
	for v in w:select "main_queue camera_ref:in" do
		return icamera.find_camera(v.camera_ref)
	end
end

function sm:update_camera()
	if dl_eid then
		local changed

		for v in w:select "scene_changed eid:in" do
			if find_directional_light(v.eid) then
				changed = true
			end
		end

		for _ in viewcamera_changed_mb:each() do
			changed = true
		end
	
		if changed then
			local maincamrea = find_main_camera()
			if maincamrea then
				update_shadow_camera(dl_eid, maincamrea)
			end
		else
			for qe in w:select "csm_queue camera_ref:in" do
				local camera = icamera.find_camera(qe.camera_ref)
				if camera then
					update_camera_matrices(camera)
				end
			end
		end
	end

end

function sm:refine_camera()
	-- local setting = ishadow.setting()
	-- for se in w:select "csm_queue primitive_filter:in"
	-- 	local se = world[eid]
	-- assert(false && "should move code new ecs")
	-- 		local filter = se.primitive_filter.result
	-- 		local sceneaabb = math3d.aabb()
	
	-- 		local function merge_scene_aabb(sceneaabb, filtertarget)
	-- 			for _, item in ipf.iter_target(filtertarget) do
	-- 				if item.aabb then
	-- 					sceneaabb = math3d.aabb_merge(sceneaabb, item.aabb)
	-- 				end
	-- 			end
	-- 			return sceneaabb
	-- 		end
	
	-- 		sceneaabb = merge_scene_aabb(sceneaabb, filter.opacity)
	-- 		sceneaabb = merge_scene_aabb(sceneaabb, filter.translucent)
	
	-- 		if math3d.aabb_isvalid(sceneaabb) then
	-- 			local camera_rc = world[se.camera_ref]._rendercache
	
	-- 			local function calc_refine_frustum_corners(rc)
	-- 				local frustm_points_WS = math3d.frustum_points(rc.viewprojmat)
	-- 				local frustum_aabb_WS = math3d.points_aabb(frustm_points_WS)
		
	-- 				local scene_frustum_aabb_WS = math3d.aabb_intersection(sceneaabb, frustum_aabb_WS)
	-- 				local max_frustum_aabb_WS = math3d.aabb_merge(sceneaabb, frustum_aabb_WS)
	-- 				local _, extents = math3d.aabb_center_extents(scene_frustum_aabb_WS)
	-- 				extents = math3d.mul(0.1, extents)
	-- 				scene_frustum_aabb_WS = math3d.aabb_expand(scene_frustum_aabb_WS, extents)
					
	-- 				local max_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, max_frustum_aabb_WS)
	-- 				local max_n, max_f = math3d.index(math3d.index(max_frustum_aabb_VS, 1), 3), math3d.index(math3d.index(max_frustum_aabb_VS, 2), 3)
	
	-- 				local scene_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, scene_frustum_aabb_WS)
	
	-- 				local minv, maxv = math3d.index(scene_frustum_aabb_VS, 1), math3d.index(scene_frustum_aabb_VS, 2)
	-- 				minv, maxv = math3d.set_index(minv, 3, max_n), math3d.set_index(maxv, 3, max_f)
	-- 				scene_frustum_aabb_VS = math3d.aabb(minv, maxv)
					
	-- 				scene_frustum_aabb_WS = math3d.aabb_transform(rc.worldmat, scene_frustum_aabb_VS)
	-- 				return math3d.aabb_points(scene_frustum_aabb_WS)
	-- 			end
	
	-- 			local aabb_corners_WS = calc_refine_frustum_corners(camera_rc)
	
	-- 			local lightdir = math3d.index(camera_rc.worldmat, 3)
	-- 			calc_shadow_camera_from_corners(aabb_corners_WS, lightdir, setting.shadowmap_size, setting.stabilize, camera_rc)
	-- 		end
	-- end
end

local function which_material(skinning)
	return skinning and gpu_skinning_material or shadow_material
end

local bgfx = require "bgfx"
local omni_stencils = {
	[0] = bgfx.make_stencil{
		TEST="EQUAL",
		FUNC_REF = 0,
	},
	[1] = bgfx.make_stencil{
		TEST="EQUAL",
		FUNC_REF = 1,
	},
}

local s = ecs.system "shadow_primitive_system"

function s:end_filter()
    for e in w:select "filter_result:in render_object:in skinning?in filter_material:in" do
        local rc = e.render_object
		local m = which_material(e.skinning)
		local fm = e.filter_material
		local fr = e.filter_result
		for qe in w:select "csm_queue primitive_filter:in" do
			for _, fn in ipairs(qe.primitive_filter) do
				if fr[fn] then
					fm[fn] = {
						fx = m.fx,
						properties = m.properties,
						state = irender.check_primitive_mode_state(rc.state, m.state),
					}
				end
			end
		end
	end
end
