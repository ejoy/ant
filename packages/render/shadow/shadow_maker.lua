-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local camerautil= require "camera.util"
local shadowutil= require "shadow.util"
local fbmgr 	= require "framebuffer_mgr"
local setting	= require "setting"

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local mathpkg 	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local math3d	= require "math3d"
local fs 		= require "filesystem"

ecs.component "csm"
	.split_ratios "real[2]"
	.index "int" (0)
	.stabilize "boolean" (true)

ecs.component "omni"	-- for point/spot light

ecs.component "csm_split_config"
	.min_ratio		"real"(0.0)
	.max_ratio		"real"(1.0)
	.pssm_lambda	"real"(1.0)
	.num_split		"int" (4)
	.ratios	 		"real[]"


ecs.component "shadow"
	.shadowmap_size "int" 	(1024)
	.bias 			"real"	(0.003)
	.normal_offset 	"real" (0)
	.depth_type 	"string"("linear")		-- "inv_z" / "linear"
	["opt"].split	"csm_split_config"

local sp = ecs.policy "shadow_config"
sp.unique_component "shadow"
sp.require_component "fb_index"

local smp = ecs.policy "shadow_make"
smp.require_component "csm"
smp.require_component "material"

smp.require_policy "render_queue"
smp.require_policy "name"

smp.require_system "shadowmaker_camera"
smp.require_system "shadow_maker"

local scp = ecs.policy "shadow_cast"
scp.require_component "can_cast"
scp.require_policy "shadow_make"
scp.require_policy "shadow_config"

local maker_camera = ecs.system "shadowmaker_camera"
maker_camera.require_system "ant.scene|primitive_filter_system"

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

local function calc_shadow_camera(view_camera, split_ratios, lightdir, shadowmap_size, stabilize, shadowcamera)
	shadowcamera.viewdir.v = lightdir

	-- frustum_desc can cache, only camera distance changed or ratios change need recalculate
	local frustum_desc = shadowutil.split_new_frustum(view_camera.frustum, split_ratios)
	local vp = mu.view_proj(view_camera, frustum_desc)

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

	shadowcamera.eyepos.v = center_WS
	--shadowcamera.updir(updir)
	shadowcamera.frustum = {
		ortho=true,
		l = min_extent[1], r = max_extent[1],
		b = min_extent[2], t = max_extent[2],
		n = min_extent[3], f = max_extent[3],
	}
end

function maker_camera:shadow_camera()
	local lightdir = shadowutil.get_directional_light_dir(world)
	if lightdir then
		local shadowentity = world:singleton_entity "shadow"
		local shadowcfg = shadowentity.shadow
		local stabilize = shadowcfg.stabilize
		local shadowmap_size = shadowcfg.shadowmap_size

		local view_camera = camerautil.main_queue_camera(world)
		local frustum = view_camera.frustum

		local split = shadowcfg.split
		local ratios = shadowutil.calc_split_distance_ratio(split.min_ratio, split.max_ratio, 
			frustum.n, frustum.f, split.pssm_lambda, split.num_split)

		for _, eid in world:each "csm" do
			local csmentity = world[eid]
			local shadowcamera = world[csmentity.camera_eid].camera
			local csm = world[eid].csm
			local ratio = ratios[csm.index]
			calc_shadow_camera(view_camera, ratio, lightdir, shadowmap_size, stabilize, shadowcamera)
			csm.split_distance_VS = shadowcamera.frustum.f - frustum.n
		end
	end
end
local sm = ecs.system "shadow_maker"
sm.require_system "ant.scene|primitive_filter_system"
sm.require_system "shadowmaker_camera"
sm.require_system "render_system"

local linear_cast_material = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast_linear.material"
local cast_material = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast.material"

local function default_csm_camera()
	return {
		type = "csm", 
		updir = mc.T_NXAXIS, 
		viewdir = mc.T_ZAXIS,
		eyepos = mc.T_ZERO_PT,
		frustum = {
			l = -1, r = 1, t = -1, b = 1,
			n = 1, f = 100, ortho = true,
		}
	}
end

local function create_csm_entity(index, viewrect, linear_shadow)
	local cameraname = "csm" .. index
	local cameraeid = world:create_entity {
		policy = {
			"ant.render|camera",
			"ant.render|name",
		},
		data = {
			camera = default_csm_camera(),
			name = cameraname
		}
	}

	return world:create_entity {
		policy = {
			"ant.render|shadow_make",
			"ant.render|render_queue",
			"ant.render|name",
		},
		data = {
			material = {ref_path = linear_shadow and linear_cast_material or cast_material},
			csm = {
				split_ratios= {0, 0},
				index 		= index,
				stabilize 	= false,
			},
			viewid = viewidmgr.get(cameraname),
			primitive_filter = {
				filter_tag = "can_cast",
			},
			camera_eid = cameraeid,
			render_target = {
				viewport = {
					rect = viewrect,
					clear_state = {
						color = 0xffffffff,
						depth = 1,
						stencil = 0,
						clear = linear_shadow and "colordepth" or "depth",
					}
				},
			},
			visible = true,
			name = "direction light shadow maker:" .. index,
		}
	}
end

local function get_render_buffers(width, height, linear_shadow)
	if linear_shadow then
		local flags = renderutil.generate_sampler_flag {
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
			flags=renderutil.generate_sampler_flag{
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
			"ant.render|shadow_config"
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

function sm:init()
	local sd = setting.get()
	local shadowsetting = sd.graphic.shadow
	local shadowmap_size= shadowsetting.size
	local depth_type 	= shadowsetting.type
	local linear_shadow = depth_type == "linear"
	local split_num 	= shadowsetting.split_num

	local seid 	= create_shadow_entity(shadowmap_size, split_num, depth_type)
	local se 	= world[seid]
	local fbidx = se.fb_index

	local viewrect = {x=0, y=0, w=shadowmap_size, h=shadowmap_size}
	for ii=1, split_num do
		local tagname = "csm" .. ii
		local csm_viewid = viewidmgr.get(tagname)
		fbmgr.bind(csm_viewid, fbidx)
		viewrect.x = (ii-1)*shadowmap_size
		create_csm_entity(ii, viewrect, linear_shadow)
	end
end

function sm:make_shadow()
	for _, eid in world:each "csm" do
		local se = world[eid]
		local filter = se.primitive_filter
		local results = filter.result
		local function replace_material(result, material)
			local mi = assetmgr.get_resource(material.ref_path)	-- must only one material content
			for i=1, result.cacheidx - 1 do
				local r = result[i]
				r.material = mi
			end
		end
	
		local shadowmaterial = se.material
		replace_material(results.opaticy, 		shadowmaterial)
		replace_material(results.translucent, 	shadowmaterial)
	end
end