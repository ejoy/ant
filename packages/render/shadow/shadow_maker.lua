-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local computil 	= require "components.util"
local camerautil= require "camera.util"
local shadowutil= require "shadow.util"

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack
local mc 		= mathpkg.constant
local fs 		= require "filesystem"
local mathbaselib= require "math3d.baselib"


local csm_comp = ecs.component "csm"
	.split_ratios "real[2]"
	.index "int" (0)
	["opt"].stabilize "boolean" (true)

function csm_comp:init()
	self.stabilize = self.stabilize or true
	self.near = 1
	self.far = 0
	return self
end

ecs.component "omni"	-- for point/spot light

ecs.component "shadow" {depend = "material"}
	.shadowmap_size "int" 	(1024)
	.bias 			"real"	(0.003)
	.normal_offset 	"real" (0)
	.depth_type 	"string"("linear")	-- "inv_z" / "linear"
	["opt"].csm 	"csm"

local maker_camera = ecs.system "shadowmaker_camera"
maker_camera.depend "primitive_filter_system"
maker_camera.dependby "filter_properties"

local function get_directional_light_dir_T()
	local ld = shadowutil.get_directional_light_dir(world)
	return ms(ld, "T")
end

--local linear_shadow = true
local function gen_ratios(distances)
	local pre_dis = 0
	local ratios = {}
	for i=1, #distances do
		local dis = distances[i]
		ratios[#ratios+1] = {pre_dis, dis}
		pre_dis = dis
	end
	ratios[#ratios+1] = {pre_dis, 1.0}
	return ratios
end

local split_distance_ratios = gen_ratios{0.18, 0.35, 0.65}
local shadowmap_size = 1024

-- local function create_crop_matrix(shadow)
-- 	local view_camera = camerautil.get_camera(world, "main_view")

-- 	local csm = shadow.csm
-- 	local csmindex = csm.index
-- 	local shadowcamera = camerautil.get_camera(world, "csm" .. csmindex)
-- 	local shadow_viewmatrix = ms:view_proj(shadowcamera)

-- 	local bb_LS = get_frustum_points(view_camera, view_camera.frustum, shadow_viewmatrix, shadow.csm.split_ratios)
-- 	local aabb = bb_LS:get "aabb"
-- 	local min, max = aabb.min, aabb.max
-- 	min[4], max[4] = 1, 1	-- as point

-- 	local _, proj = ms:view_proj(nil, shadowcamera.frustum)
-- 	local minproj, maxproj = ms(min, proj, "%", max, proj, "%TT")

-- 	local scalex, scaley = 2 / (maxproj[1] - minproj[1]), 2 / (maxproj[2] - minproj[2])
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

	local unit_pretexel = ms(maxextent, minextent, "-", {texsize, texsize, 0, 0}, "*P")
	local invunit_pretexel = ms(unit_pretexel, "rP")

	local function limit_move_in_one_texel(value)
		-- value /= unit_pretexel;
		-- value = floor( value );
		-- value *= unit_pretexel;
		return ms(value, invunit_pretexel, "*f", unit_pretexel, "*T")
	end

	local newmin = limit_move_in_one_texel(minextent)
	local newmax = limit_move_in_one_texel(maxextent)
	
	minextent[1], minextent[2] = newmin[1], newmin[2]
	maxextent[1], maxextent[2] = newmax[1], newmax[2]
end

local function calc_shadow_camera(shadow, lightdir, shadowcamera)
	local view_camera = camerautil.get_camera(world, "main_view")

	shadowcamera.viewdir(lightdir)

	local csm = shadow.csm
	-- frustum_desc can cache, only camera distance changed or ratios change need recalculate
	local frustum_desc = shadowutil.split_new_frustum(view_camera.frustum, csm.split_ratios)
	csm.split_distance_VS = frustum_desc.f - view_camera.frustum.n
	local _, _, vp = ms:view_proj(view_camera, frustum_desc, true)
	local viewfrustum = mathbaselib.new_frustum(ms, vp)
	local corners_WS = viewfrustum:points()

	local center_WS = viewfrustum:center(corners_WS)
	local min_extent, max_extent
	if csm.stabilize then
		local radius = viewfrustum:max_radius(center_WS, corners_WS)
		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
		keep_shadowmap_move_one_texel(min_extent, max_extent, shadow.shadowmap_size)
	else
		-- using camera world matrix right axis as light camera matrix up direction
		-- look at matrix up direction should select one that not easy parallel with view direction
		local shadow_viewmatrix = ms:lookat(center_WS, lightdir, nil, true)
		local minv, maxv = ms:minmax(corners_WS, shadow_viewmatrix)
		min_extent, max_extent = ms(minv, "T", maxv, "T")
	end

	shadowcamera.eyepos(center_WS)--ms(center_WS, lightdir, {-min_extent[3]}, "*+P"))
	--shadowcamera.updir(updir)
	shadowcamera.frustum = {
		ortho=true,
		l = min_extent[1], r = max_extent[1],
		b = min_extent[2], t = max_extent[2],
		n = min_extent[3], f = max_extent[3],
	}
end

function maker_camera:update()
	local lightdir = shadowutil.get_directional_light_dir(world)
	for _, eid in world:each "shadow" do
		local shadowentity = world[eid]

		local shadowcamera = camerautil.get_camera(world, shadowentity.camera_tag)
		calc_shadow_camera(shadowentity.shadow, lightdir, shadowcamera)
	end
end

local sm = ecs.system "shadow_maker"
sm.depend "primitive_filter_system"
sm.depend "shadowmaker_camera"
sm.dependby "render_system"
sm.dependby "debug_shadow_maker"

local function create_csm_entity(lightdir, index, ratios, shadowmap_size)
	local camera_tag = "csm" .. index
	camerautil.bind_camera(world, camera_tag, {
		type = "csm_shadow",
		eyepos = mc.ZERO_PT,
		viewdir = lightdir,
		updir = {0, 1, 0, 0},
		frustum = {
			ortho = true,
			l = -1, r = 1,
			b = -1, t = 1,
			n = -1, f = 1,
		},
	})

	local renderbuffers
	local cast_material_path
	if linear_shadow then
		local flags = renderutil.generate_sampler_flag {
			RT="RT_ON",
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		}

		renderbuffers = {
			{
				format = "RGBA8",
				w=shadowmap_size,
				h=shadowmap_size,
				layers=1,
				flags=flags,
			},
			{
				format = "D24S8",
				w=shadowmap_size,
				h=shadowmap_size,
				layers=1,
				flags=flags,
			},
		}


		cast_material_path = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast_linear.material"
	else
		renderbuffers = {
			{
				format = "D32F",
				w=shadowmap_size,
				h=shadowmap_size,
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
		cast_material_path = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast.material"
	end

	return world:create_entity {
		material = {
			{ref_path = cast_material_path},
		},
		shadow = {
			shadowmap_size = shadowmap_size,
			bias = 0.003,
			depth_type = "linear",
			normal_offset = 0,
			csm = {
				split_ratios= ratios,
				index 		= index,
				stabilize 	= false,
			}
		},
		viewid = viewidmgr.get(camera_tag),
		primitive_filter = {
			view_tag = "main_view",
			filter_tag = "can_cast",
		},
		camera_tag = camera_tag,
		render_target = {
			viewport = {
				rect = {x=0, y=0, w=shadowmap_size, h=shadowmap_size},
				clear_state = {
					color = 0,
					depth = 1,
					stencil = 0,
					clear = "colordepth",
				}
			},
			frame_buffer = {
				render_buffers = renderbuffers,
			}
		},
		name = "direction light shadow maker:" .. index,
	}
end

function sm:post_init()
	local lightdir = get_directional_light_dir_T()
	for ii=1, #split_distance_ratios do
		local ratio = split_distance_ratios[ii]
		create_csm_entity(lightdir, ii, ratio, shadowmap_size)
	end
end

function sm:update()
	for _, eid in world:each "shadow" do
		local sm = world[eid]
		local filter = sm.primitive_filter
		local results = filter.result
		local function replace_material(result, material)
			local mi = assetmgr.get_resource(material.ref_path)	-- must only one material content
			for i=1, result.cacheidx - 1 do
				local r = result[i]
				r.material = mi
			end
		end
	
		local shadowmaterial = sm.material
		replace_material(results.opaticy, 		shadowmaterial)
		replace_material(results.translucent, 	shadowmaterial)
	end
end