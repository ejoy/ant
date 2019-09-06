-- TODO: should move to scene package

local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local computil 	= require "components.util"
local camerautil= require "camera.util"

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

local function calc_csm_camera_bounding(view_camera, view_frustum, transform, ratios)
	local frustum_desc = split_new_frustum(view_frustum, ratios)
	
	local _, _, vp = ms:view_proj(view_camera, frustum_desc, true)

	-- we need point in light space, so the ndc to light space order is:
	-- inv(proj) -> inv(view) -> light matrix
	-- so the construct matrix should be reversed order:
	-- inv(light matrix)-> view -> proj
	vp = ms(vp, transform, "i*P")
	local frustum = mathbaselib.new_frustum(ms, vp)
	local points = frustum:points()
	local bb = mathbaselib.new_bounding(ms)
	bb:append(table.unpack(points))
	return bb
end

-- local function create_crop_matrix(shadow)
-- 	local view_camera = camerautil.get_camera(world, "main_view")

-- 	local csm = shadow.csm
-- 	local csmindex = csm.index
-- 	local shadowcamera = camerautil.get_camera(world, "csm" .. csmindex)
-- 	local shadowview_mat = ms:view_proj(shadowcamera)

-- 	local bb_LS = calc_csm_camera_bounding(view_camera, view_camera.frustum, shadowview_mat, shadow.csm.split_ratios)
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

local function calc_shadow_frustum(shadow)
	local view_camera = camerautil.get_camera(world, "main_view")

	local csm = shadow.csm
	local csmindex = csm.index
	local shadowcamera = camerautil.get_camera(world, "csm" .. csmindex)
	local shadowview_mat = ms:view_proj(shadowcamera)

	local bb_LS = calc_csm_camera_bounding(view_camera, view_camera.frustum, shadowview_mat, shadow.csm.split_ratios)

	local aabb = bb_LS:get "aabb"
	local min, max = aabb.min, aabb.max
	min[4], max[4] = 1, 1	-- as point

	if csm.stabilize then
		local texsize = 1 / shadow.shadowmap_size

		local worldunit_pretexel = ms(max, min, "-", {texsize, texsize, 0, 0}, "*P")
		local invworldunit_pretexel = ms(worldunit_pretexel, "rP")

		local function limit_move_in_one_texel(value)
			-- value /= worldunit_pretexel;
			-- value = floor( value );
			-- value *= worldunit_pretexel;
			return ms(value, invworldunit_pretexel, "*f", worldunit_pretexel, "*T")
		end

		local newmin = limit_move_in_one_texel(min)
		local newmax = limit_move_in_one_texel(max)
		
		min[1], min[2] = newmin[1], newmin[2]
		max[1], max[2] = newmax[1], newmax[2]
	end

	return {
		ortho = true,
		l = min[1], r = max[1],
		b = min[2], t = max[2],
		n = min[3], f = max[3],
	}
end

function maker_camera:update()
	local dl = world:first_entity "directional_light"
	local lightdir = ms(dl.rotation, "dnP")
	
	for _, eid in world:each "shadow" do
		local shadowentity = world[eid]

		local shadowcamera = camerautil.get_camera(world, shadowentity.camera_tag)
		shadowcamera.viewdir(lightdir)
		shadowcamera.eyepos(mc.ZERO_PT)

		shadowcamera.frustum = calc_shadow_frustum(shadowentity.shadow)
		--shadowcamera.crop_matrix = create_crop_matrix(shadowentity.shadow)
	end
end

local sm = ecs.system "shadow_maker"
sm.depend "primitive_filter_system"
sm.depend "shadowmaker_camera"
sm.dependby "render_system"
sm.dependby "debug_shadow_maker"

local function create_csm_entity(lightdir, index, ratios, shadowmap_size, camera_far)
	camera_far = camera_far or 10000
	local camera_tag = "csm" .. index
	local camera = camerautil.bind_camera(world, camera_tag, {
		type = "csm_shadow",
		eyepos = mc.ZERO_PT,
		viewdir = lightdir,
		updir = {0, 1, 0, 0},
		frustum = {
			ortho = true,
			-- we calculate width/height value in crop_matrix
			l = -1, r = 1,
			b = -1, t = 1,
			n = -camera_far, f = camera_far,
		},
	})

	camera.crop_matrix = mc.mat_identity
	return world:create_entity {
		material = {
			{ref_path = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast.material"},
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
					clear = "depth",
				}
			},
			frame_buffer = {
				render_buffers = {
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
			}
		},
		name = "direction light shadow maker:" .. index,
	}
end

function sm:post_init()
	local d_light = world:first_entity "directional_light"
	local lightdir = ms(d_light.rotation, "dnT")
	local ratios = {
		{0, 0.05},
		{0.05, 0.15},
		{0.15, 0.45},
		{0.45, 1},
	}
	for ii=1, #ratios do
		local ratio = ratios[ii]
		create_csm_entity(lightdir, ii, ratio, 1024, 20)
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

local function	csm_shadow_debug_frustum()
	for _, seid in world:each "shadow" do
		local e = world[seid]
		local camera = camerautil.get_camera(world, e.camera_tag)
		local _, _, vp = ms:view_proj(camera, camera.frustum, true)

		local frustum = mathbaselib.new_frustum(ms, vp)
		computil.create_frustum_entity(world, frustum, "csm frusutm part" .. e.shadow.csm.index, nil, 0xff0f0f0f)
	end
end

local function main_view_debug_frustum()
	local mq = world:first_entity "main_queue"
	--create_frustum_debug(mq, "main view frustum", 0xff0000ff)
	local camera = camerautil.get_camera(world, mq.camera_tag)

	local colors = {
		0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffff00,
	}

	for _, seid in world:each "shadow" do
		local s = world[seid]

		local csm = s.shadow.csm
		local frustum_desc = split_new_frustum(camera.frustum, csm.split_ratios)
		local _, _, vp = ms:view_proj(camera, frustum_desc, true)
		local frustum = mathbaselib.new_frustum(ms, vp)
		computil.create_frustum_entity(world, frustum, "main view part" .. csm.index, nil, colors[csm.index])
	end
end

function debug_sm:post_init()
	main_view_debug_frustum()
	csm_shadow_debug_quad()
	csm_shadow_debug_frustum()
end