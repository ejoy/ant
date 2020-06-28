-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local samplerutil= require "sampler"
local shadowutil= require "shadow.util"
local fbmgr 	= require "framebuffer_mgr"
local setting	= require "setting"

local mathpkg 	= import_package "ant.math"
local mc		= mathpkg.constant
local math3d	= require "math3d"
local icamera	= world:interface "ant.camera|camera"

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
		return math3d.totable(
			math3d.mul(math3d.floor(math3d.mul(value, invunit_pretexel)), unit_pretexel))
	end

	local newmin = limit_move_in_one_texel(minextent)
	local newmax = limit_move_in_one_texel(maxextent)
	
	minextent[1], minextent[2] = newmin[1], newmin[2]
	maxextent[1], maxextent[2] = newmax[1], newmax[2]
end

local function calc_shadow_camera(viewmat, frustum, split_ratios, lightdir, shadowmap_size, stabilize, sc_eid)
	-- frustum_desc can cache, only camera distance changed or ratios change need recalculate
	local newfrustum = shadowutil.split_new_frustum(frustum, split_ratios)
	local vp = math3d.mul(math3d.projmat(newfrustum), viewmat)

	local corners_WS = math3d.frustum_points(vp)

	local center_WS = math3d.frustum_center(corners_WS)
	local min_extent, max_extent
	if stabilize then
		local radius = math3d.frusutm_max_radius(corners_WS, center_WS)
		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
		keep_shadowmap_move_one_texel(min_extent, max_extent, shadowmap_size)
	else
		-- using camera world matrix right axis as light camera matrix up direction
		-- look at matrix up direction should select one that not easy parallel with view direction
		local shadow_viewmatrix = math3d.lookto(center_WS, lightdir)
		local minv, maxv = math3d.minmax(corners_WS, shadow_viewmatrix)
		min_extent, max_extent = math3d.totable(minv), math3d.totable(maxv)
	end

	local rc = world[sc_eid]._rendercache
	rc.worldmat = math3d.matrix{r=math3d.torotation(lightdir), t=center_WS}
	rc.srt.m = rc.worldmat
	rc.frustum = {
		ortho=true,
		l = min_extent[1], r = max_extent[1],
		b = min_extent[2], t = max_extent[2],
		n = min_extent[3], f = max_extent[3],
	}
end

local function update_shadow_camera(l, view_camera_eid)
	local lightdir = math3d.inverse(l.direction)
	local shadowentity = world:singleton_entity "shadow"
	local shadowcfg = shadowentity.shadow
	local stabilize = shadowcfg.stabilize
	local shadowmap_size = shadowcfg.shadowmap_size

	local frustum = icamera.get_frustum(view_camera_eid)
	local viewmat = icamera.viewmat(view_camera_eid)
	local split = shadowcfg.split
	local ratios = shadowutil.calc_split_distance_ratio(split.min_ratio, split.max_ratio, 
		frustum.n, frustum.f, split.pssm_lambda, split.num_split)

	for _, eid in world:each "csm" do
		local csmentity = world[eid]
		local sc_eid = csmentity.camera_eid
		local csmfrustum = icamera.get_frustum(sc_eid)
		local csm = world[eid].csm
		local ratio = ratios[csm.index]
		calc_shadow_camera(viewmat, frustum, ratio, lightdir, shadowmap_size, stabilize, sc_eid)
		csm.split_distance_VS = csmfrustum.f - frustum.n
	end
end

local sm = ecs.system "shadow_system"

local imateral = world:interface "ant.asset|imaterial"
local icamera = world:interface "ant.camera|camera"
local function create_csm_entity(index, viewrect, fbidx, linear_shadow)
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
			"ant.render|shadow_make_policy",
			"ant.render|render_queue",
			"ant.general|name",
		},
		data = {
			csm = {
				split_ratios= {0, 0},
				index 		= index,
				stabilize 	= false,
			},
			primitive_filter = world.component "primitive_filter" {
				filter_type = "cast_shadow",
			},
			camera_eid = cameraeid,
			render_target = world.component "render_target" {
				viewid = viewidmgr.get(cameraname),
				view_mode = "s",
				viewport = {
					rect = viewrect,
					clear_state = {
						color = 0xffffffff,
						depth = 1,
						stencil = 0,
						clear = linear_shadow and "colordepth" or "depth",
					}
				},
				fb_idx = fbidx,
			},
			visible = true,
			name = "csm" .. index,
		},
		writeable = {
			render_target = true,
		}
	}
end

local function get_render_buffers(width, height, linear_shadow)
	if linear_shadow then
		local flags = samplerutil.sampler_flag {
			RT="RT_ON",
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		}

		return {
			fbmgr.create_rb{
				format = "RGBA8",
				w=width,
				h=height,
				layers=1,
				flags=flags,
			},
			fbmgr.create_rb {
				format = "D24S8",
				w=width,
				h=height,
				layers=1,
				flags=flags,
			},
		}

	end

	return {
		fbmgr.create_rb{
			format = "D32F",
			w=width,
			h=height,
			layers=1,
			flags=samplerutil.sampler_flag{
				RT="RT_ON",
				MIN="LINEAR",
				MAG="LINEAR",
				U="CLAMP",
				V="CLAMP",
				COMPARE="COMPARE_LEQUAL",
				BOARD_COLOR="0",
			},
		}
	}
end

local function create_shadow_entity(shadowmap_size, split_num, depth_type)
	local height = shadowmap_size
	local width = shadowmap_size * split_num

	local min_ratio, max_ratio 	= 0.02, 1.0
	local pssm_lambda 			= 3

	return world:create_entity {
		policy = {
			"ant.render|shadow_config_policy"
		},
		data = {
			shadow = {
				shadowmap_size 	= shadowmap_size,
				bias 			= 0.003,
				depth_type 		= depth_type,
				normal_offset 	= 0,
				split = {
					min_ratio 	= min_ratio,
					max_ratio 	= max_ratio,
					pssm_lambda = pssm_lambda,
					num_split 	= split_num,
					ratios 		= {},
				}
			},
			fb_index = fbmgr.create{
				render_buffers = get_render_buffers(width, height, depth_type == "linear")
			}
		}
	}
end

local shadow_material
function sm:init()
	local sd = setting:data()
	local shadowsetting = sd.graphic.shadow
	local shadowmap_size= shadowsetting.size
	local depth_type 	= shadowsetting.type
	local linear_shadow = depth_type == "linear"
	local split_num 	= shadowsetting.split_num

	shadow_material = imateral.load(linear_shadow and 
		"/pkg/ant.resources/materials/shadow/csm_cast_linear.material" or 
		"/pkg/ant.resources/materials/shadow/csm_cast.material")

	local seid 	= create_shadow_entity(shadowmap_size, split_num, depth_type)
	local se 	= world[seid]
	local fbidx = se.fb_index

	for ii=1, split_num do
		local vr = {x=(ii-1)*shadowmap_size, y=0, w=shadowmap_size, h=shadowmap_size}
		create_csm_entity(ii, vr, fbidx, linear_shadow)
	end
end

local modify_mailboxs = {}

function sm:post_init()
	local mq = world:singleton_entity "main_queue"
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "transform", mq.camera_eid}
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "frusutm", mq.camera_eid}
	modify_mailboxs[#modify_mailboxs+1] = world:sub{"component_changed", "directional_light", world:singleton_entity_id "directional_light"}

	--pub an event to make update_shadow_camera be called
	world:pub{"component_changed", "directional_light", world:singleton_entity_id "directional_light"}
end

function sm:create_camera_from_mainview()
	for _, mb in ipairs(modify_mailboxs) do
		for _ in mb:each() do
			local dl = world:singleton_entity "directional_light"
			local mq = world:singleton_entity "main_queue"
			update_shadow_camera(dl, mq.camera_eid)
		end
	end
end

local function replace_material(result, material)
	local items = result.items
	for eid, item in pairs(items) do
		local newitem = {}
		for n, v in pairs(item) do
			newitem[n] = v
		end
		newitem.fx 			= material.fx
		newitem.properties 	= material.properties
		--TODO: primitive mode should follow origin material setting
		--newitem.state 		= material._state
		items[eid]			= newitem
	end
end

function sm:refine_filter()
	for _, eid in world:each "csm" do
		local se = world[eid]
		local filter = se.primitive_filter
		local results = filter.result


		replace_material(results.opaticy, 		shadow_material)
		replace_material(results.translucent, 	shadow_material)
	end
end