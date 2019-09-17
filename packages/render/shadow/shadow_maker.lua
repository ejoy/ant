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
local mu		= mathpkg.util
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

local function get_directional_light_dir()
	local d_light = world:first_entity "directional_light"
	return ms(d_light.rotation, "dniP")
end

local function get_directional_light_dir_T()
	local ld = get_directional_light_dir()
	return ms(ld, "T")
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
	newmax[1], newmax[2] = newmax[1], newmax[2]
end

local function calc_shadow_camera(shadow, lightdir, shadowcamera)
	local view_camera = camerautil.get_camera(world, "main_view")

	shadowcamera.viewdir(lightdir)

	local csm = shadow.csm
	local corner_WS = get_frustum_points(view_camera, view_camera.frustum, csm.split_ratios)
	local eyepos_WS = calc_shadow_camera_eye_pos(corner_WS, lightdir)
	shadowcamera.eyepos(eyepos_WS)
	
	local shadow_viewmatrix = ms(eyepos_WS, lightdir, "LP")

	local corner_LS = {}
	for _, c in ipairs(corner_WS) do
		corner_LS[#corner_LS+1] = ms(shadow_viewmatrix, c, "*P")
	end

	local aabbmin, aabbmax = ms:minmax(table.unpack(corner_LS))
	local min, max = ms(aabbmin, "T", aabbmax, "T")

	if csm.stabilize then
		keep_shadowmap_move_one_texel(min, max, shadow.shadowmap_size)
	end

	shadowcamera.frustum = {
		ortho = true,
		l = min[1], r = max[1],
		b = min[2], t = max[2],
		n = min[3], f = max[3],
	}
end

function maker_camera:update()
	local lightdir = get_directional_light_dir()

	-- local viewcamera = camerautil.get_camera(world, "main_view")
	-- local _, _, vp = ms:view_proj(viewcamera, viewcamera.frustum, true)

	-- local origin = {0, 0, 0, 1}

	-- local function to_ndc(pos_WS, viewproj)
	-- 	local pos_CS = ms(viewproj, pos_WS, "*T")
	-- 	local h_coord = pos_CS[4]
	-- 	local pos_NDC = {pos_CS[1] / h_coord, pos_CS[2]/h_coord, pos_CS[3]/h_coord, h_coord}
	-- 	return pos_NDC
	-- end

	-- local origin_NDC_VIEW = to_ndc(origin, vp)
	-- local t0 = to_ndc({1, 1, 2, 1}, vp)
	-- local t1 = to_ndc({2, 1, 1, 1}, vp)
	-- print(string.format("origin point view camera ndc:(%f, %f, %f, %f)", 
	-- 	origin_NDC_VIEW[1], origin_NDC_VIEW[2], origin_NDC_VIEW[3], origin_NDC_VIEW[4]))

	for _, eid in world:each "shadow" do
		local shadowentity = world[eid]

		local shadowcamera = camerautil.get_camera(world, shadowentity.camera_tag)
		calc_shadow_camera(shadowentity.shadow, lightdir, shadowcamera)

		-- local _, _, light_vp = ms:view_proj(shadowcamera, shadowcamera.frustum, true)
		-- local origin_NDC_LIGHT = to_ndc(origin, light_vp)
		-- print(string.format("origin in light ndc[%d]:(%f, %f, %f, %f)", shadowentity.shadow.csm.index, 
		-- 	origin_NDC_LIGHT[1], origin_NDC_LIGHT[2], origin_NDC_LIGHT[3], origin_NDC_LIGHT[4]))
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
	camerautil.bind_camera(world, camera_tag, {
		type = "csm_shadow",
		eyepos = mc.ZERO_PT,
		viewdir = lightdir,
		updir = {0, 1, 0, 0},
		frustum = {
			ortho = true,
			l = -1, r = 1,
			b = -1, t = 1,
			n = -camera_far, f = camera_far,
		},
	})

	return world:create_entity {
		material = {
			{ref_path = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast.material"},
		},
		shadow = {
			shadowmap_size = shadowmap_size,
			bias = 0.03,
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
	local lightdir = get_directional_light_dir_T()
	local ratios = {
		{0, 0.15},
		{0.15, 0.35},
		{0.35, 0.5},
		{0.5, 1},
	}
	for ii=1, #ratios do
		local ratio = ratios[ii]
		create_csm_entity(lightdir, ii, ratio, 512, 20)
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
function debug_sm:camera_state_handler()
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