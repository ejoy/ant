-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"

local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"
local icamera	= world:interface "ant.camera|camera"
local ilight	= world:interface "ant.render|light"
local ishadow	= world:interface "ant.render|ishadow"
local irender	= world:interface "ant.render|irender"

local iom		= world:interface "ant.objcontroller|obj_motion"
local ipf		= world:interface "ant.scene|iprimitive_filter"
local irq		= world:interface "ant.render|irenderqueue"
-- local function create_crop_matrix(shadow)
-- 	local view_camera = world.main_queue_camera(world)

-- 	local csm = shadow.csm
-- 	local csmindex = csm.index
-- 	local shadowcamera = world[shadow.camera_eid].camera
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

local function calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, camera_rc)
	local center_WS = math3d.points_center(corners_WS)
	local min_extent, max_extent

	camera_rc.viewmat = math3d.lookto(center_WS, lightdir, camera_rc.updir) --math3d.index(camera.worldmat, 1))
	camera_rc.worldmat = math3d.inverse(camera_rc.viewmat)
	camera_rc.srt.id = camera_rc.worldmat

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
	camera_rc.projmat = math3d.projmat(camera_rc.frustum)
	camera_rc.viewprojmat = math3d.mul(camera_rc.projmat, camera_rc.viewmat)
end

local function calc_shadow_camera(camera, frustum, lightdir, shadowmap_size, stabilize, sc_eid)
	local vp = math3d.mul(math3d.projmat(frustum), camera.viewmat)

	local corners_WS = math3d.frustum_points(vp)
	local updir = math3d.index(camera.worldmat, 1)
	local camera_rc = world[sc_eid]._rendercache
	camera_rc.updir.id = updir
	calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, camera_rc)
end

local function update_shadow_camera(dl_eid, camera)
	local lightdir = iom.get_direction(dl_eid)
	local setting = ishadow.setting()
	local viewfrustum = camera.frustum
	local csmfrustums = ishadow.calc_split_frustums(viewfrustum)

	for _, eid in world:each "csm" do
		local e = world[eid]
		local csm = e.csm
		local cf = csmfrustums[csm.index]
		calc_shadow_camera(camera, cf, lightdir, setting.shadowmap_size, setting.stabilize, e.camera_eid)
		csm.split_distance_VS = cf.f - viewfrustum.n
	end
end

local sm = ecs.system "shadow_system"

local function create_csm_entity(index, viewrect, fbidx, depth_type)
	local cameraname = "csm" .. index
	local cameraeid = icamera.create {
			updir 	= mc.YAXIS,
			viewdir = mc.ZAXIS,
			eyepos 	= mc.ZERO_PT,
			frustum = {
				l = -1, r = 1, t = -1, b = 1,
				n = 1, f = 100, ortho = true,
			},
			name = cameraname
		}

	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|csm_policy",
			"ant.general|name",
		},
		data = {
			csm = {
				index = index,
				split_distance_VS = 0,
			},
			primitive_filter = {
				filter_type = "cast_shadow",
			},
			camera_eid = cameraeid,
			render_target = {
				viewid = viewidmgr.get(cameraname),
				view_mode = "s",
				view_rect = viewrect,
				clear_state = {
					color = 0xffffffff,
					depth = 1,
					stencil = 0,
					clear = depth_type == "linear" and "CD" or "D",
				},
				fb_idx = fbidx,
			},
			visible = true,
			name = "csm" .. index,
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
		local eid = create_csm_entity(ii, vr, fbidx, dt)
		irq.set_view_clear(eid, "D", nil, 1, nil, true)
	end
end

local modify_mailboxs = {}

function sm:post_init()
	local mq = world:singleton_entity "main_queue"
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "transform", mq.camera_eid}
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "frusutm", mq.camera_eid}
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "directional_light", ilight.directional_light()}

	--pub an event to make update_shadow_camera be called
	world:pub{"component_changed", "directional_light", ilight.directional_light()}
end

function sm:update_camera()
	local mq = world:singleton_entity "main_queue"
	local c = world[mq.camera_eid]._rendercache

	local leid = ilight.directional_light()
	for _, ceid in world:each "csm" do
		world[ceid].visible = leid ~= nil
	end

	if leid then
		update_shadow_camera(leid, c)
	end
end

function sm:refine_camera()
	local setting = ishadow.setting()
	for _, eid in world:each "csm" do
		local se = world[eid]
		if se.visible then
			local filter = se.primitive_filter.result
			local sceneaabb = math3d.aabb()
	
			local function merge_scene_aabb(sceneaabb, filtertarget)
				for _, item in ipf.iter_target(filtertarget) do
					if item.aabb then
						sceneaabb = math3d.aabb_merge(sceneaabb, item.aabb)
					end
				end
				return sceneaabb
			end
	
			sceneaabb = merge_scene_aabb(sceneaabb, filter.opaticy)
			sceneaabb = merge_scene_aabb(sceneaabb, filter.translucent)
	
			if math3d.aabb_isvalid(sceneaabb) then
				local camera_rc = world[se.camera_eid]._rendercache
	
				local function calc_refine_frustum_corners(rc)
					local frustm_points_WS = math3d.frustum_points(rc.viewprojmat)
					local frustum_aabb_WS = math3d.points_aabb(frustm_points_WS)
		
					local scene_frustum_aabb_WS = math3d.aabb_intersection(sceneaabb, frustum_aabb_WS)
					local max_frustum_aabb_WS = math3d.aabb_merge(sceneaabb, frustum_aabb_WS)
					local _, extents = math3d.aabb_center_extents(scene_frustum_aabb_WS)
					extents = math3d.mul(0.1, extents)
					scene_frustum_aabb_WS = math3d.aabb_expand(scene_frustum_aabb_WS, extents)
					
					local max_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, max_frustum_aabb_WS)
					local max_n, max_f = math3d.index(math3d.index(max_frustum_aabb_VS, 1), 3), math3d.index(math3d.index(max_frustum_aabb_VS, 2), 3)
	
					local scene_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, scene_frustum_aabb_WS)
	
					local minv, maxv = math3d.index(scene_frustum_aabb_VS, 1), math3d.index(scene_frustum_aabb_VS, 2)
					minv, maxv = math3d.set_index(minv, 3, max_n), math3d.set_index(maxv, 3, max_f)
					scene_frustum_aabb_VS = math3d.aabb(minv, maxv)
					
					scene_frustum_aabb_WS = math3d.aabb_transform(rc.worldmat, scene_frustum_aabb_VS)
					return math3d.aabb_points(scene_frustum_aabb_WS)
				end
	
				local aabb_corners_WS = calc_refine_frustum_corners(camera_rc)
	
				local lightdir = math3d.index(camera_rc.worldmat, 3)
				calc_shadow_camera_from_corners(aabb_corners_WS, lightdir, setting.shadowmap_size, setting.stabilize, camera_rc)
			end
		end
	end
end

local function which_material(eid)
	if world[eid].skinning_type == "GPU" then
		return gpu_skinning_material
	else
		return shadow_material
	end
end

local spt = ecs.transform "shadow_primitive_transform"

function spt.process_entity(e)
	e.primitive_filter.insert_item = function (filter, fxtype, eid, rc)
		local results = filter.result
		if rc then
			rc.eid = eid
			local material = which_material(eid)
			ipf.add_item(results[fxtype].items, eid, setmetatable({
				fx = material.fx,
				properties = material.properties or false,
				state = irender.check_primitive_mode_state(rc.state, material.state),
			}, {__index=rc}))
		else
			ipf.remove_item(results.opaticy.items, eid)
			ipf.remove_item(results.translucent.items, eid)
		end
	end
end