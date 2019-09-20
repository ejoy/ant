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
local mu		= mathpkg.util
local fs 		= require "filesystem"
local mathbaselib= require "math3d.baselib"

local bgfx		= require "bgfx"

--local linear_shadow = true

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

local function get_directional_light_dir()
	local d_light = world:first_entity "directional_light"
	return ms(d_light.rotation, "dP")
end

local function get_directional_light_dir_T()
	local ld = get_directional_light_dir()
	return ms(ld, "T")
end

local function calc_split_points(points, ratios)
	local function sub_point(lhs, rhs)
		return {
			lhs[1] - rhs[1],
			lhs[2] - rhs[2],
			lhs[3] - rhs[3],
		}
	end

	local function mul_point_scalar(pt, scalar)
		return {
			pt[1] * scalar,
			pt[2] * scalar,
			pt[3] * scalar,
		}
	end

	local function add_point(lhs, rhs)
		return {
			lhs[1] + rhs[1],
			lhs[2] + rhs[2],
			lhs[3] + rhs[3],
		}
	end
	local newpoints = {}
	for i=1, 4 do
		local cornerRay = sub_point(points[i + 4], points[i])
		local nearCornerRay = mul_point_scalar(cornerRay, ratios[1]);
		local farCornerRay  = mul_point_scalar(cornerRay, ratios[2]);
		newpoints[i + 4] 	= add_point(points[i], farCornerRay);
		newpoints[i] 		= add_point(points[i], nearCornerRay);
	end

	return newpoints
end
	
local function split_new_frustum(view_frustum, ratios)
	assert(view_frustum.ortho == nil or view_frustum.ortho == false)

	local near_ratio, far_ratio = ratios[1], ratios[2]
	local frustum = {}
	for k, v in pairs(view_frustum) do
		frustum[k] = v
	end

	local z_len = view_frustum.f - view_frustum.n
	frustum.n = view_frustum.n + near_ratio * z_len
	frustum.f = view_frustum.n + far_ratio * z_len

	assert(frustum.fov)
	return frustum
end

local function get_frustum_points(view_camera, view_frustum, ratios)
	local frustum_desc = split_new_frustum(view_frustum, ratios)
	
	local _, _, vp = ms:view_proj(view_camera, frustum_desc, true)
	local frustum = mathbaselib.new_frustum(ms, vp)
	return frustum:points()
end

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

local function calc_shadow_camera_eye_pos(corners_WS, lightdir)
	local bb = mathbaselib.new_bounding(ms)
	bb:append(table.unpack(corners_WS))
	local s = bb:get "sphere"
	local radius = s[4]
	s[4] = 1
	return ms(s, {-radius}, lightdir, "*+P")
end

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
	local frustum_desc = split_new_frustum(view_camera.frustum, csm.split_ratios)
	csm.split_distance_VS = frustum_desc.f - view_camera.frustum.n
	local _, _, vp = ms:view_proj(view_camera, frustum_desc, true)
	local viewfrustum = mathbaselib.new_frustum(ms, vp)
	local corners_WS = viewfrustum:points()

	local center_WS = viewfrustum:center(corners_WS)

	--local updir
	local min_extent, max_extent
	if false then --csm.stabilize then
		local radius = viewfrustum:max_radius(center_WS, corners_WS)
		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
		--updir = mu.YAXIS
		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
		keep_shadowmap_move_one_texel(min_extent, max_extent, shadow.shadowmap_size)
	else
		-- using camera world matrix right axis as light camera matrix up direction
		--updir = ms:base_axes(lightdir)
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
	local lightdir = get_directional_light_dir()
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
				format = "D16F",
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
				split_ratios = ratios,
				index = index,
				stabilize = true,
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
	local ratios = {
		{0, 0.15},
		{0.15, 0.35},
		{0.35, 0.5},
		{0.5, 1},
	}
	for ii=1, #ratios do
		local ratio = ratios[ii]
		create_csm_entity(lightdir, ii, ratio, 512)
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

local debug_sm = ecs.system "debug_shadow_maker"
debug_sm.depend "shadowmaker_camera"

ecs.tag "shadow_quad"

local function csm_shadow_debug_quad()
	local fbsize = world.args.fb_size
	local fbheight = fbsize.h

	local quadsize = 192
	local off_y = 0 --fbheight - 192
	local quadmaterial = fs.path "/pkg/ant.resources/depiction/materials/shadow/shadowmap_quad.material"
	for _, eid in world:each "shadow" do
		local se = world[eid]
		local csm = se.shadow.csm
		local idx = csm.index
		local off_x = (idx-1) * quadsize

		local rect = {x=off_x, y=off_y, w=quadsize, h=quadsize}
		local q_eid = computil.create_quad_entity(world, rect, quadmaterial, nil, "csm_quad"..idx)
		world:add_component(q_eid, "shadow_quad", true)
		local qe = world[q_eid]
		local quad_material = qe.material[0]
		local properties = quad_material.properties 
		if properties == nil then
			properties = {}
			quad_material.properties = properties
		end
		local textures = properties.textures
		if textures == nil then
			textures = {}
			properties.textures = textures
		end

		textures["s_shadowmap"] = {
			type = "texture", name = "csm render buffer", stage = 0,
			handle = se.render_target.frame_buffer.render_buffers[1].handle,
		}
	end
end

ecs.tag "shadow_debug"

local frustum_colors = {
	0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffff00,
}

local function	csm_shadow_debug_frustum()
	for _, seid in world:each "shadow" do
		local e = world[seid]
		local camera = camerautil.get_camera(world, e.camera_tag)
		local _, _, vp = ms:view_proj(camera, camera.frustum, true)

		local color = frustum_colors[e.shadow.csm.index]
		local frustum = mathbaselib.new_frustum(ms, vp)
		local f_eid = computil.create_frustum_entity(world, 
			frustum, "csm frusutm part" .. e.shadow.csm.index, nil, color)
		world:add_component(f_eid, "shadow_debug", true)

		local a_eid = computil.create_axis_entity(world, mu.srt(nil, ms(camera.viewdir, "DT"), ms(camera.eyepos, "T")), color)
		world:add_component(a_eid, "shadow_debug", true)
	end
end

local function main_view_debug_frustum()
	local mq = world:first_entity "main_queue"
	--create_frustum_debug(mq, "main view frustum", 0xff0000ff)
	local camera = camerautil.get_camera(world, mq.camera_tag)

	for _, seid in world:each "shadow" do
		local s = world[seid]

		local csm = s.shadow.csm
		local frustum_desc = split_new_frustum(camera.frustum, csm.split_ratios)
		local _, _, vp = ms:view_proj(camera, frustum_desc, true)
		local frustum = mathbaselib.new_frustum(ms, vp)
		local f_eid = computil.create_frustum_entity(world, frustum, "main view part" .. csm.index, nil, frustum_colors[csm.index])
		world:add_component(f_eid, "shadow_debug", true)
	end
end

function debug_sm:post_init()
	csm_shadow_debug_quad()
end

ecs.mark("record_camera_state", "camera_state_handler")

local function find_csm_entity(index)
	for _, seid in world:each "shadow" do
		local se = world[seid]
		if se.shadow.csm.index == index then
			return seid
		end
	end
end

local function get_split_distance(index)
	local se = world[find_csm_entity(index)]

	local viewcamera = camerautil.get_camera(world, "main_view")
	local viewdistance = viewcamera.frustum.f - viewcamera.frustum.n

	local ratios = se.shadow.csm.split_ratios
	local n = viewcamera.frustum.n + ratios[1] * viewdistance
	local f = viewcamera.frustum.n + ratios[2] * viewdistance
	return n, f
end

local function create_debug_entity()
	for eid in world:each_mark "record_camera_state" do
		local e = assert(world[eid])
		assert(e.main_queue)

		local function remove_eids(eids)
			for _, eid in ipairs(eids)do
				world:remove_entity(eid)
			end
		end

		local debug_shadow_eids = {}
		for _, seid in world:each "shadow_debug" do
			debug_shadow_eids[#debug_shadow_eids+1] = seid
		end

		remove_eids(debug_shadow_eids)

		main_view_debug_frustum()
		csm_shadow_debug_frustum()
	end
end

local function print_points(points)
	for idx, c in ipairs(points) do
		print(string.format("\tpoint[%d]:[%f, %f, %f]", idx, c[1], c[2], c[3]))
	end
end

local function print_frustum_points(frustum)
	print_points(frustum:points())
end

local function calc_frustum_center(frustum)
	local center = {0, 0, 0, 1}
	for _, c in ipairs(frustum:points()) do
		center[1] = center[1] + c[1]
		center[2] = center[2] + c[2]
		center[3] = center[3] + c[3]
	end

	center[1] = center[1] / 8
	center[2] = center[2] / 8
	center[3] = center[3] / 8

	return center
end

local blit_shadowmap_viewid = viewidmgr.generate "blit_shadowmap"

ecs.mark("read_back_blit", "read_back_blit_handler")
ecs.mark("read_back_sm", "read_back_sm_handler")

local function check_shadow_matrix()
	local csm1 = world[find_csm_entity(1)]

	local lightdir = get_directional_light_dir()
	print("light direction:", ms(lightdir, "V"))

	local viewcamera = camerautil.get_camera(world, "main_view")
	print("eye posision:", ms(viewcamera.eyepos, "V"))
	print("view direction:", ms(viewcamera.viewdir, "V"))

	local camera_2_origin = ms:length(mc.ZERO_PT, viewcamera.eyepos)
	print("check eye position to [0, 0, 0] distance:", camera_2_origin)

	local dis_n, dis_f = get_split_distance(1)
	print("csm1 distance:", dis_n, dis_f)

	if dis_n <= camera_2_origin and camera_2_origin <= dis_f then
		print("origin is on csm1")
	else
		print("origin is not on csm1")
	end

	local split_frustum_desc = split_new_frustum(viewcamera.frustum, csm1.shadow.csm.split_ratios)
	local _, _, vp = ms:view_proj(viewcamera, split_frustum_desc, true)
	local split_frustum = mathbaselib.new_frustum(ms, vp)

	local center = calc_frustum_center(split_frustum)

	print(string.format("view split frusutm corners, center:[%f, %f, %f]", center[1], center[2], center[3]))
	print_frustum_points(split_frustum)

	local lightmatrix = ms(center, lightdir, "LP")
	local corners_LS = {}
	local minextent, maxextent = {}, {}
	for _, c in ipairs(split_frustum:points()) do
		local c_LS = ms(lightmatrix, c, "*T")
		corners_LS[#corners_LS+1] = c_LS
		minextent[1] = minextent[1] and math.min(minextent[1], c_LS[1]) or c_LS[1]
		minextent[2] = minextent[2] and math.min(minextent[2], c_LS[2]) or c_LS[2]
		minextent[3] = minextent[3] and math.min(minextent[3], c_LS[3]) or c_LS[3]

		maxextent[1] = maxextent[1] and math.max(maxextent[1], c_LS[1]) or c_LS[1]
		maxextent[2] = maxextent[2] and math.max(maxextent[2], c_LS[2]) or c_LS[2]
		maxextent[3] = maxextent[3] and math.max(maxextent[3], c_LS[3]) or c_LS[3]
	end

	print("light space corner points")
	print_points(corners_LS)

	local frustum_desc = {
		ortho = true,
		l = minextent[1], r = maxextent[1],
		b = minextent[2], t = maxextent[2],
		n = minextent[3], f = maxextent[3],
	}

	print(string.format("split camera frustum:[l=%f, r=%f, b=%f, t=%f, n=%f, f=%f]", 
	frustum_desc.l, frustum_desc.r, 
	frustum_desc.b, frustum_desc.t, 
	frustum_desc.n, frustum_desc.f))

	local _, _, newvp = ms:view_proj({eyepos=center, viewdir=lightdir}, frustum_desc, true)
	local new_light_frustum = mathbaselib.new_frustum(ms, newvp)
	computil.create_frustum_entity(world, new_light_frustum, "lua calc view frustum", nil, 0xff0000ff)

	---------------------------------------------------------------------------------------------------------

	local shadowcamera = camerautil.get_camera(world, csm1.camera_tag)
	print("shadow camera view direction:", ms(shadowcamera.viewdir, "V"))
	print("shadow camera position:", ms(shadowcamera.eyepos, "V"))

	local shadowcamera_frustum_desc = shadowcamera.frustum
	print(string.format("shadow camera frustum:[l=%f, r=%f, b=%f, t=%f, n=%f, f=%f]", 
		shadowcamera_frustum_desc.l, shadowcamera_frustum_desc.r, 
		shadowcamera_frustum_desc.b, shadowcamera_frustum_desc.t, 
		shadowcamera_frustum_desc.n, shadowcamera_frustum_desc.f))

	local _, _, shadow_viewproj = ms:view_proj(shadowcamera, shadowcamera.frustum, true)
	local shadowcamera_frustum = mathbaselib.new_frustum(ms, shadow_viewproj)

	print("shadow view frustm point")
	print_frustum_points(shadowcamera_frustum)
	computil.create_frustum_entity(world, shadowcamera_frustum, "view frustum", nil, 0xffffff00)

	-------------------------------------------------------------------------------------------------
	-- test shadow matrix
	local pt = {-0.00009, -0.01307, 0.1544} --mc.ZERO_PT
	local worldmat = {
		0.0, 0.0, -20.02002, -20,
	}
	local origin_CS = ms(shadow_viewproj, mc.ZERO_PT, "*T")
	print(string.format("origin clip space:[%f, %f, %f, %f]", origin_CS[1], origin_CS[2], origin_CS[3], origin_CS[4]))
	local origin_NDC = {
		origin_CS[1] / origin_CS[4], 
		origin_CS[2] / origin_CS[4], 
		origin_CS[3] / origin_CS[4], 
		origin_CS[4] / origin_CS[4]
	}
	print(string.format("origin ndc space:[%f, %f, %f, %f]", origin_NDC[1], origin_NDC[2], origin_NDC[3], origin_NDC[4]))

	local shadow_matrix = ms(shadowutil.shadow_crop_matrix, shadow_viewproj, "*P")
	local origin_CS_With_Crop = ms(shadow_matrix, {0, 0, 0.55, 1}, "*T")
	print(string.format("origin clip space with corp:[%f, %f, %f, %f]", 
		origin_CS_With_Crop[1], origin_CS_With_Crop[2], origin_CS_With_Crop[3], origin_CS_With_Crop[4]))

	local origin_NDC_With_Crop = {
		origin_CS_With_Crop[1] / origin_CS_With_Crop[4], 
		origin_CS_With_Crop[2] / origin_CS_With_Crop[4], 
		origin_CS_With_Crop[3] / origin_CS_With_Crop[4], 
		origin_CS_With_Crop[4] / origin_CS_With_Crop[4],
	}
	print(string.format("origin ndc space with crop:[%f, %f, %f, %f]", 
		origin_NDC_With_Crop[1], origin_NDC_With_Crop[2], origin_NDC_With_Crop[3], origin_NDC_With_Crop[4]))
	------------------------------------------------------------------------------------------------------------------------
	-- read the shadow map back
	if linear_shadow then
		local size = csm1.shadow.shadowmap_size
		
		local memory_handle = bgfx.memory_texture(size * size * 4)
		local rb_handle = renderutil.create_renderbuffer {
			w = size,
			h = size,
			layers = 1,
			format = "RGBA8",
			flags = renderutil.generate_sampler_flag {
				BLIT="BLIT_AS_DST",
				BLIT_READBACK="BLIT_READBACK_ON",
				MIN="POINT",
				MAG="POINT",
				U="CLAMP",
				V="CLAMP",
			}
		}

		bgfx.blit(blit_shadowmap_viewid, rb_handle, 0, 0, csm1.render_target.frame_buffer.render_buffers[1].handle)
		bgfx.read_texture(rb_handle, memory_handle)

		world:mark(-1, "read_back_blit", {memory_handle, origin_NDC_With_Crop, size})
	end
end

local function log_split_distance()
	for i=1, 4 do
		local n, f = get_split_distance(i)
		print(string.format("csm%d, distance[%f, %f]", i, n, f))
	end
end

function debug_sm:read_back_blit_handler()
	for eid, info in world:each_mark "read_back_blit" do
		world:mark(eid, "read_back_sm", info)
	end
end

function debug_sm:read_back_sm_handler()
	for eid, info in world:each_mark "read_back_sm" do
		local memory_handle = info[1]
		local pt = info[2]
		local sm_size = info[3]

		local depth = pt[3]
		local x, y = pt[1], pt[2]
		local fx, fy = math.floor(x * sm_size), math.floor(y * sm_size)
		local cx, cy = math.ceil(x * sm_size), math.ceil(y * sm_size)

		local depth0 = memory_handle[fy*sm_size+fx]
		local depth1 = memory_handle[fy*sm_size+cx]

		local depth2 = memory_handle[cy*sm_size+fx]
		local depth3 = memory_handle[cy*sm_size+cx]

		-- local fs_local = require "filesystem.local"
		-- local f = fs_local.open(fs.path "tmp.txt", "wb")
		-- for ii=1, sm_size do
		-- 	for jj=1, sm_size do
		-- 		local v = memory_handle[(ii-1)*sm_size+jj]
		-- 		f:write(v == 0 and 0 or 1)
		-- 	end
		-- 	f:write("\n")
		-- end
		-- f:close()

		print("depth:", depth)
		print("depth0:", depth0, "depth1:", depth1, "depth2:", depth2, "depth3:", depth3)
	end
end

function debug_sm:camera_state_handler()
	log_split_distance()
	create_debug_entity()

	--check_shadow_matrix()
end