-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local samplerutil= require "sampler"
local fbmgr 	= require "framebuffer_mgr"
local setting	= require "setting"

local mc 		= import_package "ant.math".constant
local math3d	= require "math3d"
local icamera	= world:interface "ant.camera|camera"
local ilight	= world:interface "ant.render|light"
local ishadow	= world:interface "ant.render|ishadow"

local iom		= world:interface "ant.objcontroller|obj_motion"
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

local function calc_shadow_camera(camera, frustum, lightdir, shadowmap_size, stabilize, sc_eid)
	local vp = math3d.mul(math3d.projmat(frustum), camera.viewmat)

	local corners_WS = math3d.frustum_points(vp)

	local center_WS = math3d.frustum_center(corners_WS)
	local min_extent, max_extent
	local rc = world[sc_eid]._rendercache
	rc.viewmat = math3d.lookto(center_WS, lightdir, math3d.index(camera.worldmat, 1))
	rc.worldmat = math3d.inverse(rc.viewmat)
	rc.srt.id = rc.worldmat
	
	if stabilize then
		local radius = math3d.frustum_max_radius(corners_WS, center_WS)
		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
		keep_shadowmap_move_one_texel(min_extent, max_extent, shadowmap_size)
	else
		local minv, maxv = math3d.minmax(corners_WS, rc.viewmat)
		min_extent, max_extent = math3d.tovalue(minv), math3d.tovalue(maxv)
	end

	rc.frustum = {
		ortho=true,
		l = min_extent[1], r = max_extent[1],
		b = min_extent[2], t = max_extent[2],
		n = min_extent[3], f = max_extent[3],
	}
	rc.projmat = math3d.projmat(rc.frustum)
	rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
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
local imaterial = world:interface "ant.asset|imaterial"
function sm:init()
	local fbidx = ishadow.fb_index()
	local s, dt = ishadow.shadowmap_size(), ishadow.depth_type()

	shadow_material = imaterial.load("/pkg/ant.resources/materials/shadow/csm_cast.material", {shadow_type=dt})
	for ii=1, ishadow.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx, dt)
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

	-- for _, mb in ipairs(modify_mailboxs) do
	-- 	for _ in mb:each() do
			update_shadow_camera(ilight.directional_light(), c)
	-- 	end
	-- end
end

local spt = ecs.transform "shadow_primitive_transform"
function spt.process_entity(e)
	e.primitive_filter.insert_item = function (filter, fxtype, eid, rc)
		local results = filter.result
		if rc then
			results[fxtype].items[eid] = setmetatable({
				fx = shadow_material.fx,
				properties = shadow_material.properties,
			}, {__index=rc})
		else
			results.opaticy.items[eid] = nil
			results.translucent.items[eid] = nil
		end
	end
end