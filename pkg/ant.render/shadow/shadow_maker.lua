local ecs 	= ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings".setting
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
local renderutil= require "util"
local sm = ecs.system "shadow_system"
if not ENABLE_SHADOW then
	renderutil.default_system(sm, 	"init",
									"init_world",
									"entity_init",
									"entity_remove",
									"update_camera",
									--"refine_filter",
									"refine_camera",
									"render_submit",
									"camera_usage",
									"update_filter")
	return
end

local assetmgr	= import_package "ant.asset"

local queuemgr	= require "queue_mgr"
local viewidmgr = require "viewid_mgr"
--local mu		= mathpkg.util
local mc 		= import_package "ant.math".constant
local idrawindirect = ecs.import.interface "ant.render|idrawindirect"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local R         = ecs.clibs "render.render_material"
local icamera	= ecs.import.interface "ant.camera|icamera"
local ishadow	= ecs.import.interface "ant.render|ishadow"
local irender	= ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"
local fbmgr		= require "framebuffer_mgr"
local INV_Z<const> = true

local csm_matrices			= {mc.IDENTITY_MAT, mc.IDENTITY_MAT, mc.IDENTITY_MAT, mc.IDENTITY_MAT}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))
--[[ local scene_aabb = math3d.ref(math3d.aabb())
local aabb_tick = 0 ]]
local function update_camera_matrices(camera, light_view)
	camera.viewmat.m = light_view
	camera.projmat.m = math3d.projmat(camera.frustum, INV_Z)
	camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
end

local function set_worldmat(srt, mat)
	math3d.unmark(srt.worldmat)
	srt.worldmat = math3d.marked_matrix(mat)
end

local function calc_csm_matrix_attrib(csmidx, vp)
	return math3d.mul(ishadow.crop_matrix(csmidx), vp)
end

-- bgfx method
local function update_csm_frustum(lightdir, shadowmap_size, csm_frustum, shadow_ce, main_camera, scene_aabb)
	iom.set_rotation(shadow_ce, math3d.torotation(lightdir))
	set_worldmat(shadow_ce.scene, shadow_ce.scene)
	local light_world = shadow_ce.scene.worldmat
	local light_view = math3d.inverse(light_world)
	local intersected_aabb = scene_aabb
	local aabb_points = math3d.aabb_points(intersected_aabb)
	local light_frustum_min, light_frustum_max = math3d.minmax(aabb_points, light_view)
	local frustum_ortho = {
		l = 1, r = -1,
		t = 1, b = -1,
		n = -main_camera.camera.frustum.f, f = main_camera.camera.frustum.f,
		ortho = true,
	}
	local ortho_proj = math3d.projmat(frustum_ortho, INV_Z)
	local min_proj, max_proj = math3d.transformH(ortho_proj, light_frustum_min, 1), math3d.transformH(ortho_proj, light_frustum_max, 1)

	local minp, maxp = math3d.tovalue(min_proj), math3d.tovalue(max_proj)

	local scalex, scaley = 2 / (maxp[1] - minp[1]), 2 / (maxp[2] - minp[2])

--[[ 	local quantizer = 64
	scalex, scaley = 64 / math.ceil(quantizer / scalex),  64 / math.ceil(quantizer / scaley) ]]

	local offsetx, offsety = 0.5 * (maxp[1] + minp[1]) * scalex, 0.5 * (maxp[2] + minp[2]) * scaley

--[[ 	local half_size = shadowmap_size * 0.5
	offsetx, offsety = math.ceil(offsetx * half_size) / half_size, math.ceil(offsety * half_size) / half_size
 ]]

	local crop = math3d.matrix{
	 	scalex, 0, 0, 0,
	 	0, scaley, 0, 0,
	 	0, 0, 1, 0,
	 	-offsetx, -offsety, 0, 1
	}
	local camera = shadow_ce.camera
 	camera.viewmat.m = light_view
	camera.projmat.m = math3d.mul(crop, ortho_proj) 
	camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
end


local function cacl_intersected_aabb(main_camera, height)
  	local world_frustum_points = math3d.frustum_points(main_camera.viewprojmat)
	local lbf, ltf, rbf, rtf = math3d.array_index(world_frustum_points, 1), math3d.array_index(world_frustum_points, 2), math3d.array_index(world_frustum_points, 3), math3d.array_index(world_frustum_points, 4)
	local lbn, ltn, rbn, rtn = math3d.array_index(world_frustum_points, 5), math3d.array_index(world_frustum_points, 6), math3d.array_index(world_frustum_points, 7), math3d.array_index(world_frustum_points, 8)
 	local ratio_lbn = (math3d.index(lbn, 2) - height) / (math3d.index(lbn, 2) - math3d.index(lbf, 2))
	local ratio_lbf = (math3d.index(lbn, 2) - 0) / (math3d.index(lbn, 2) - math3d.index(lbf, 2))
	local ratio_ltn = (math3d.index(ltn, 2) - height) / (math3d.index(ltn, 2) - math3d.index(ltf, 2))
	local ratio_ltf = (math3d.index(ltn, 2) - 0) / (math3d.index(ltn, 2) - math3d.index(ltf, 2))
	local ratio_rbn = (math3d.index(rbn, 2) - height) / (math3d.index(rbn, 2) - math3d.index(rbf, 2))
	local ratio_rbf = (math3d.index(rbn, 2) - 0) / (math3d.index(rbn, 2) - math3d.index(rbf, 2))
	local ratio_rtn = (math3d.index(rtn, 2) - height) / (math3d.index(rtn, 2) - math3d.index(rtf, 2))
	local ratio_rtf = (math3d.index(rtn, 2) - 0) / (math3d.index(rtn, 2) - math3d.index(rtf, 2))
 	local lbnn, lbff = math3d.add(lbn, math3d.mul(math3d.sub(lbf, lbn), ratio_lbn)), math3d.add(lbn, math3d.mul(math3d.sub(lbf, lbn), ratio_lbf))
	local ltnn, ltff = math3d.add(ltn, math3d.mul(math3d.sub(ltf, ltn), ratio_ltn)), math3d.add(ltn, math3d.mul(math3d.sub(ltf, ltn), ratio_ltf))
	local rbnn, rbff = math3d.add(rbn, math3d.mul(math3d.sub(rbf, rbn), ratio_rbn)), math3d.add(rbn, math3d.mul(math3d.sub(rbf, rbn), ratio_rbf))
	local rtnn, rtff = math3d.add(rtn, math3d.mul(math3d.sub(rtf, rtn), ratio_rtn)), math3d.add(rtn, math3d.mul(math3d.sub(rtf, rtn), ratio_rtf)) 
	local aabb_min, aabb_max = math3d.minmax(math3d.array_vector({lbnn, lbff, ltnn, ltff, rbnn, rbff, rtnn, rtff})) 
	return math3d.aabb(aabb_min, aabb_max) 
end

local function update_shadow_frustum(dl, main_camera)
	local lightdir = iom.get_direction(dl)
	local shadow_setting = ishadow.setting()
	local csm_frustums = ishadow.calc_split_frustums(main_camera.camera.frustum)
	local scene_aabb = cacl_intersected_aabb(main_camera.camera, shadow_setting.height)

	for qe in w:select "csm:in camera_ref:in" do
		local csm = qe.csm
		local csm_frustum = csm_frustums[csm.index]
		local shadow_ce <close> = w:entity(qe.camera_ref, "camera:in scene:in")
		update_csm_frustum(lightdir, shadow_setting.shadowmap_size, csm_frustum, shadow_ce, main_camera, scene_aabb)
		csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
		split_distances_VS[csm.index] = csm_frustum.f
	end
end 

-- microsoft method
--[[ local function calc_ortho_minmax(light_view, world_frustum_points, shadowmap_size, world_scene_aabb)
	local world_frustum_points_min, world_frustum_points_max = math3d.minmax(world_frustum_points)
	local world_frustum_aabb = math3d.aabb(world_frustum_points_min, world_frustum_points_max)
	local intersected_aabb = math3d.aabb_intersection(world_frustum_aabb, world_scene_aabb)
	local intersected_aabb_points = math3d.aabb_points(intersected_aabb)
	local light_ortho_min, light_ortho_max = math3d.minmax(intersected_aabb_points, light_view)
	local near, far = math3d.index(light_ortho_min, 3), math3d.index(light_ortho_max, 3)
	local diagonal = math3d.sub(math3d.array_index(world_frustum_points, 1), math3d.array_index(world_frustum_points, 8))
	local bound = math3d.length(diagonal)
	diagonal = math3d.vector(bound, bound, bound)

	local offset = math3d.mul(math3d.sub(diagonal, math3d.sub(light_ortho_max, light_ortho_min)), 0.5)
	offset = math3d.vector(math3d.index(offset, 1), math3d.index(offset, 2), 0)
	light_ortho_max = math3d.add(light_ortho_max, offset)
	light_ortho_min = math3d.sub(light_ortho_min, offset)
	local world_unit_per_texel = bound / shadowmap_size
	local vworld_unit_per_texel = math3d.vector(world_unit_per_texel, world_unit_per_texel, 0)

	light_ortho_min = math3d.mul(light_ortho_min, math3d.reciprocal(vworld_unit_per_texel))
	light_ortho_min = math3d.floor(light_ortho_min)
	light_ortho_min = math3d.mul(light_ortho_min, vworld_unit_per_texel)
	light_ortho_max = math3d.mul(light_ortho_max, math3d.reciprocal(vworld_unit_per_texel))
	light_ortho_max = math3d.floor(light_ortho_max)
	light_ortho_max = math3d.mul(light_ortho_max, vworld_unit_per_texel)
	
	return light_ortho_min, light_ortho_max, near, far
end

local function update_csm_frustum(lightdir, shadowmap_size, csm_frustum, shadow_ce, main_view, world_scene_aabb)
	iom.set_rotation(shadow_ce, math3d.torotation(lightdir))
	set_worldmat(shadow_ce.scene, shadow_ce.scene)

	local light_world = shadow_ce.scene.worldmat
	local light_view = math3d.inverse(light_world)
	local main_viewproj = math3d.mul(math3d.projmat(csm_frustum, INV_Z), main_view)

	local world_frustum_points = math3d.frustum_points(main_viewproj)

	local light_ortho_min, light_ortho_max, near, far = calc_ortho_minmax(light_view, world_frustum_points, shadowmap_size, world_scene_aabb)
	local camera = shadow_ce.camera
	local f = camera.frustum
	local minx, miny = math3d.index(light_ortho_min, 1, 2)
	local maxx, maxy = math3d.index(light_ortho_max, 1, 2) 
	f.l, f.b, f.n = minx, miny, near
	f.r, f.t, f.f = maxx, maxy, far
	update_camera_matrices(camera, light_view)
end 

local function update_shadow_frustum(dl, main_camera)

	local lightdir = iom.get_direction(dl)
	local setting = ishadow.setting()
	local csm_frustums = ishadow.calc_split_frustums(main_camera.frustum)
	local main_view = main_camera.viewmat
	local world_scene_aabb = math3d.aabb()
	for e in w:select "render_object:in bounding:in main_queue_cull:absent" do
		if e.bounding.scene_aabb and e.bounding.scene_aabb ~= mc.NULL and math3d.aabb_isvalid(e.bounding.scene_aabb) then
			local ccc, eee = math3d.aabb_center_extents(e.bounding.scene_aabb)
			local cc, ee = math3d.aabb_center_extents(world_scene_aabb)
			if not math3d.aabb_isvalid(world_scene_aabb) then
				world_scene_aabb = e.bounding.scene_aabb
			else
				world_scene_aabb = math3d.aabb_merge(world_scene_aabb, e.bounding.scene_aabb)
			end
		end
	end
	for qe in w:select "csm:in camera_ref:in" do
		local csm = qe.csm
		local csm_frustum = csm_frustums[csm.index]
		local shadow_ce <close> = w:entity(qe.camera_ref, "camera:in scene:in")
		csm_frustum.n = 1
		update_csm_frustum(lightdir, setting.shadowmap_size, csm_frustum, shadow_ce, main_view, world_scene_aabb)
		csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
		split_distances_VS[csm.index] = csm_frustum.f
	end
end 
 ]]
-- MJP method
--[[ local function update_shadow_frustum(dl, main_camera)

	local lightdir = iom.get_direction(dl)
	local shadow_setting = ishadow.setting()
	local csm_frustums = ishadow.calc_split_frustums(main_camera.frustum)
	for qe in w:select "csm:in camera_ref:in" do
		local main_world = math3d.inverse(main_camera.viewmat)
		local pos, dir
		local updir = math3d.index(main_world, 1)
		local csm = qe.csm
		local csm_frustum = csm_frustums[csm.index]
		local shadow_ce <close> = w:entity(qe.camera_ref, "camera:in scene:in")
		local frustum_corners_world = math3d.frustum_points(main_camera.viewprojmat)
		local prev_split_dist, split_dist = shadow_setting.split_ratios[csm.index][1], shadow_setting.split_ratios[csm.index][2]
		local frustum_corners_table = {}
		for idx = 1, 4 do
			local corner_ray = math3d.sub(math3d.array_index(frustum_corners_world, idx), math3d.array_index(frustum_corners_world, idx + 4))
			local near_corner_ray = math3d.mul(corner_ray, prev_split_dist)
			local far_corner_ray = math3d.mul(corner_ray, split_dist)
			frustum_corners_table[idx + 4] = math3d.add(math3d.array_index(frustum_corners_world, idx + 4), near_corner_ray)
			frustum_corners_table[idx] = math3d.add(math3d.array_index(frustum_corners_world, idx + 4), far_corner_ray)
		end 

		local frustum_center = math3d.vector(0, 0, 0)

		for idx = 1, 8 do
			frustum_center = math3d.add(frustum_center, frustum_corners_table[idx])
		end
		
		frustum_center = math3d.mul(frustum_center, 0.125)
		pos = frustum_center
		dir = math3d.sub(frustum_center, lightdir)
		iom.set_view(shadow_ce, pos, dir, updir)
		set_worldmat(shadow_ce.scene, shadow_ce.scene)

		local light_world = shadow_ce.scene.worldmat
		local light_view = math3d.inverse(light_world)

		local aabb_min, aabb_max = math3d.minmax(math3d.array_vector(frustum_corners_table), light_view)

		local cascade_extents = math3d.sub(aabb_max, aabb_min)

		local shadow_camera_pos = math3d.add(frustum_center, math3d.mul(lightdir, -math3d.index(aabb_min, 3)))


		local f = shadow_ce.camera.frustum
		f.l, f.b, f.n = math3d.index(aabb_min, 1), math3d.index(aabb_min, 2), 0
		f.r, f.t, f.f = math3d.index(aabb_max, 1), math3d.index(aabb_max, 2), math3d.index(cascade_extents, 3)

		pos = shadow_camera_pos
		dir = frustum_center
		iom.set_view(shadow_ce, pos, dir, updir)
		set_worldmat(shadow_ce.scene, shadow_ce.scene)

		light_world = shadow_ce.scene.worldmat
		light_view = math3d.inverse(light_world)
		update_camera_matrices(shadow_ce.camera, light_view)
		csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
		split_distances_VS[csm.index] = csm_frustum.f
	end
end ]]

local function create_clear_shadowmap_queue(fbidx)
	local rb = fbmgr.get_rb(fbidx, 1)
	local ww, hh = rb.w, rb.h
	ecs.create_entity{
		policy = {
			"ant.render|postprocess_queue",
			"ant.general|name",
		},
		data = {
			render_target = {
                clear_state = {
                    depth = 0,
                    clear = "D",
                },
				fb_idx = fbidx,
				viewid = viewidmgr.get "csm_fb",
				view_rect = {x=0, y=0, w=ww, h=hh},
			},
			clear_sm = true,
			queue_name = "clear_sm",
			name = "clear_sm",
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
	ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|cull",
			"ant.render|csm_queue",
			"ant.general|name",
		},
		data = {
			csm = {
				index = index,
			},
			camera_ref = camera_ref,
			render_target = {
				viewid = viewidmgr.get(csmname),
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				clear_state = {
					clear = "",
				},
				fb_idx = fbidx,
			},
			visible = false,
			queue_name = queuename,
			[queuename] = true,
			name = "csm" .. index,
			camera_depend = true
		},
	}
end

local shadow_material
local gpu_skinning_material
local shadow_sm_material
local shadow_heap_material
local shadow_indirect_material
function sm:init()
	local fbidx = ishadow.fb_index()
	local s = ishadow.shadowmap_size()
	create_clear_shadowmap_queue(fbidx)
	shadow_material = imaterial.load_res "/pkg/ant.resources/materials/depth.material"
	gpu_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/depth_skin.material"
	shadow_sm_material = imaterial.load_res "/pkg/ant.resources/materials/depth_sm.material"
	shadow_heap_material = imaterial.load_res "/pkg/ant.resources/materials/depth_heap.material"
	shadow_indirect_material = imaterial.load_res "/pkg/ant.resources/materials/depth_indirect.material"
	for ii=1, ishadow.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx)
	end
end

-- local function main_camera_changed(ceid)
-- 	local camera <close> = w:entity(ceid, "camera:in").camera
-- 	local csmfrustums = ishadow.calc_split_frustums(camera.frustum)
-- 	for cqe in w:select "csm:in" do
-- 		local csm = cqe.csm
-- 		local idx = csm.index
-- 		local cf = assert(csmfrustums[csm.index])
-- 		csm.view_frustum = cf
-- 		split_distances_VS[idx] = cf.f
-- 	end
-- end

local function set_csm_visible(enable)
	for v in w:select "csm visible?out" do
		v.visible = enable
	end
end

function sm:entity_init()
	for e in w:select "INIT make_shadow directional_light light:in" do
		local csm_dl = w:first("csm_directional_light light:in")
		if csm_dl == nil then
			e.csm_directional_light = true
			w:extend(e, "csm_directional_light?out")
			set_csm_visible(true)
		else
			--error("already have 'make_shadow' directional light")
		end
	end
end

function sm:entity_remove()
	for _ in w:select "REMOVED csm_directional_light" do
		set_csm_visible(false)
	end
end

local function commit_csm_matrices_attribs()
	local sa = imaterial.system_attribs()
	sa:update("u_csm_matrix", csm_matrices)
	sa:update("u_csm_split_distances", split_distances_VS)
end

function sm:init_world()
	local sa = imaterial.system_attribs()
	sa:update("s_shadowmap", fbmgr.get_rb(ishadow.fb_index(), 1).handle)
	sa:update("u_shadow_param1", ishadow.shadow_param())
	sa:update("u_shadow_param2", ishadow.shadow_param2())
end

function sm:update_camera_depend()
	local dl = w:first("csm_directional_light light:in scene:in scene_changed?in")
	if dl then
		local mq = w:first("main_queue camera_ref:in")
		local camera <close> = w:entity(mq.camera_ref, "camera:in scene:in")
		--update_shadow_camera(dl, camera.camera)
		update_shadow_frustum(dl, camera)
		commit_csm_matrices_attribs()
	end
end



function sm:refine_camera()
--[[ 	for se in w:select "render_object:in csm1_queue_cull eid:in bounding?in view_visible?in" do
		local t = 1
	end

	for se in w:select "render_object:in csm1_queue_cull:absent eid:in bounding?in view_visible?in" do
		local t = 1
	end ]]


	-- local setting = ishadow.setting()
	-- for se in w:select "csm primitive_filter:in"
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
	-- 				local max_n, max_f = math3d.index(math3d.array_index(max_frustum_aabb_VS, 1), 3), math3d.index(math3d.array_index(max_frustum_aabb_VS, 2), 3)
	
	-- 				local scene_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, scene_frustum_aabb_WS)
	
	-- 				local minv, maxv = math3d.array_index(scene_frustum_aabb_VS, 1), math3d.array_index(scene_frustum_aabb_VS, 2)
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

function sm:render_submit()
	local viewid = viewidmgr.get "csm_fb"
	bgfx.touch(viewid)
end

function sm:camera_usage()
	-- local sa = imaterial.system_attribs()
	-- local mq = w:first("main_queue camera_ref:in")
	-- local camera <close> = w:entity(mq.camera_ref, "camera:in")
	-- sa:update("u_main_camera_matrix",camera.camera.viewmat)	local scene_aabb = math3d.aabb()
--[[ 	local scene_aabb = {}
	local groups = {}
	local tmp_eids = {}
	for e in w:select "scene:in hitch:in" do
		local cur_group = e.hitch.group
		if not groups[cur_group] then groups[cur_group] = {} end
		local hitch_worldmats = groups[cur_group]
		hitch_worldmats[#hitch_worldmats+1] = e.scene.worldmat
	end

	for gid, wms in pairs(groups) do
        --local select_tag = "view_visible:in scene_update:in scene:in bounding:in eid:in"
		local select_tag = "hitch_tag:in scene:in bounding:in eid:in"
		local g = ecs.group(gid)
        g:enable("hitch_tag")
		for ee in w:select(select_tag) do
			tmp_eids[ee.eid] = true
			local is_aabb_valid = ee.bounding.aabb and ee.bounding.aabb ~= mc.NULL and math3d.aabb_isvalid(ee.bounding.aabb)
			if is_aabb_valid then
				for _, wm in pairs(wms) do
					local world_aabb = ee.bounding.scene_aabb
					local tmp_aabb = math3d.aabb_transform(wm, world_aabb)
					if not math3d.aabb_isvalid(scene_aabb) then
						scene_aabb = tmp_aabb
					else
						scene_aabb = math3d.aabb_merge(scene_aabb, tmp_aabb)
					end
				end
			end
        end
        g:disable("hitch_tag")
	end ]]
end

local function which_material(skinning, indirect)
	if indirect then
		return shadow_indirect_material.object
	end
	if skinning then
		return gpu_skinning_material.object
	end
	
		return shadow_material.object		
	--return skinning and gpu_skinning_material or shadow_material
end

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

function sm:update_filter()
    for e in w:select "filter_result visible_state:in render_object:in filter_material:in material:in skinning?in indirect?in bounding:in" do
		if not e.visible_state["cast_shadow"] then
			goto continue
		end
		local mt = assetmgr.resource(e.material)
		local ro = e.render_object

		local mat_ptr
		if mt.fx.setting.shadow_cast == "on" then
			local mo = which_material(e.skinning, e.indirect)
			local fm = e.filter_material
			local newstate = irender.check_set_state(mo, fm.main_queue:get_material(), function (d, s)
				d.PT, d.CULL = s.PT, d.CULL
				d.DEPTH_TEST = "GREATER"
				return d
			end)

			local mi = mo:instance()
			mi:set_state(newstate)
			if e.indirect then
				local draw_indirect_type = idrawindirect.get_draw_indirect_type(e.indirect)
				mi.u_draw_indirect_type = math3d.vector(draw_indirect_type)
			end
			fm["csm1_queue"] = mi
			fm["csm2_queue"] = mi
			fm["csm3_queue"] = mi
			fm["csm4_queue"] = mi

			mat_ptr = mi:ptr()
		end

		R.set(ro.rm_idx, queuemgr.material_index "csm1_queue", mat_ptr)
		R.set(ro.rm_idx, queuemgr.material_index "csm2_queue", mat_ptr)
		R.set(ro.rm_idx, queuemgr.material_index "csm3_queue", mat_ptr)
		R.set(ro.rm_idx, queuemgr.material_index "csm4_queue", mat_ptr)
	    ::continue::
	end
end


