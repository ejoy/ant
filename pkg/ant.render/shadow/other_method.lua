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
		local shadow_ce <close> = world:entity(qe.camera_ref, "camera:in scene:in")
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
		local shadow_ce <close> = world:entity(qe.camera_ref, "camera:in scene:in")
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

-- function sm:refine_camera()
--  	for se in w:select "render_object:in csm1_queue_cull eid:in bounding?in view_visible?in" do
-- 		local t = 1
-- 	end

-- 	for se in w:select "render_object:in csm1_queue_cull:absent eid:in bounding?in view_visible?in" do
-- 		local t = 1
-- 	end

-- 	local setting = ishadow.setting()
-- 	for se in w:select "csm primitive_filter:in"
-- 		local se = world[eid]
-- 		assert(false and "should move code new ecs")
-- 			local filter = se.primitive_filter.result
-- 			local sceneaabb = math3d.aabb()

-- 			local function merge_scene_aabb(sceneaabb, filtertarget)
-- 				for _, item in ipf.iter_target(filtertarget) do
-- 					if item.aabb then
-- 						sceneaabb = math3d.aabb_merge(sceneaabb, item.aabb)
-- 					end
-- 				end
-- 				return sceneaabb
-- 			end

-- 			sceneaabb = merge_scene_aabb(sceneaabb, filter.opacity)
-- 			sceneaabb = merge_scene_aabb(sceneaabb, filter.translucent)

-- 			if math3d.aabb_isvalid(sceneaabb) then
-- 				local camera_rc = world[se.camera_ref]._rendercache

-- 				local function calc_refine_frustum_corners(rc)
-- 					local frustm_points_WS = math3d.frustum_points(rc.viewprojmat)
-- 					local frustum_aabb_WS = math3d.points_aabb(frustm_points_WS)

-- 					local scene_frustum_aabb_WS = math3d.aabb_intersection(sceneaabb, frustum_aabb_WS)
-- 					local max_frustum_aabb_WS = math3d.aabb_merge(sceneaabb, frustum_aabb_WS)
-- 					local _, extents = math3d.aabb_center_extents(scene_frustum_aabb_WS)
-- 					extents = math3d.mul(0.1, extents)
-- 					scene_frustum_aabb_WS = math3d.aabb_expand(scene_frustum_aabb_WS, extents)

-- 					local max_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, max_frustum_aabb_WS)
-- 					local max_n, max_f = math3d.index(math3d.array_index(max_frustum_aabb_VS, 1), 3), math3d.index(math3d.array_index(max_frustum_aabb_VS, 2), 3)

-- 					local scene_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, scene_frustum_aabb_WS)

-- 					local minv, maxv = math3d.array_index(scene_frustum_aabb_VS, 1), math3d.array_index(scene_frustum_aabb_VS, 2)
-- 					minv, maxv = math3d.set_index(minv, 3, max_n), math3d.set_index(maxv, 3, max_f)
-- 					scene_frustum_aabb_VS = math3d.aabb(minv, maxv)

-- 					scene_frustum_aabb_WS = math3d.aabb_transform(rc.worldmat, scene_frustum_aabb_VS)
-- 					return math3d.aabb_points(scene_frustum_aabb_WS)
-- 				end

-- 				local aabb_corners_WS = calc_refine_frustum_corners(camera_rc)

-- 				local lightdir = math3d.index(camera_rc.worldmat, 3)
-- 				calc_shadow_camera_from_corners(aabb_corners_WS, lightdir, setting.shadowmap_size, setting.stabilize, camera_rc)
-- 			end
-- 	end
-- end

--function sm:camera_usage()
	-- local mq = w:first("main_queue camera_ref:in")
	-- local camera <close> = world:entity(mq.camera_ref, "camera:in")
	-- imaterial.system_attrib_update("u_main_camera_matrix",camera.camera.viewmat)	local scene_aabb = math3d.aabb()
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
        --local select_tag = "view_visible:in scene:in bounding:in eid:in"
		local select_tag = "hitch_tag:in scene:in bounding:in eid:in"
		ig.enable(gid, "hitch_tag", true)
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
		ig.enable(gid, "hitch_tag", false)
	end ]]
--end

--local omni_stencils = {
--	[0] = bgfx.make_stencil{
--		TEST="EQUAL",
--		FUNC_REF = 0,
--	},
--	[1] = bgfx.make_stencil{
--		TEST="EQUAL",
--		FUNC_REF = 1,
--	},
--}

--[[ 
local function update_csm_frustum(lightdir, shadowmap_size, csm_frustum, shadow_ce, intersected_aabb, main_view)

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
		local main_csm_proj = math3d.projmat(csm_frustum)
		local main_csm_vp   = math3d.mul(main_csm_proj, main_view)
		local frustum_points = math3d.frustum_points(main_csm_vp)
		local light_frustum_min, light_frustum_max = math3d.minmax(frustum_points, light_view)
		local frustum_ortho = {
			l = 1, r = -1,
			t = 1, b = -1,
			n = -csm_frustum.f, f = csm_frustum.f,
			ortho = true,
		}
		local ortho_proj = math3d.projmat(frustum_ortho, INV_Z)
		local min_proj, max_proj = math3d.transformH(ortho_proj, light_frustum_min, 1), math3d.transformH(ortho_proj, light_frustum_max, 1)	
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
end ]]
