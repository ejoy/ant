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

local s = ecs.component "shadow" {depend = "material"}
	.shadowmap_size "int" 	(1024)
	.bias 			"real"	(0.003)
	.normal_offset 	"vector"(0, 0, 0, 0)
	.depth_type 	"string"("linear")	-- "inv_z" / "linear"
	["opt"].csm 	"csm"

local function init_shadow_material_properties(material, shadow)
	local properties = material.properties
	if properties == nil then
		properties = {}
		material.properties = properties
	end
	local uniforms = properties.uniforms
	if uniforms == nil then
		uniforms = {}
		properties.uniforms = uniforms
	end

	uniforms.u_normaloffset = {type="v4", name = "shadowmap normal offset", value = shadow.normal_offset}

	local textures = properties.textures
	if textures == nil then
		textures = {}
		properties.textures = textures
	end

	local csm = assert(shadow.csm)
	csm.crop_matrix = {}
end

function s:postinit(e)
	init_shadow_material_properties(e.material, self)

end

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
	frustum.f = view_frustum.f + far_ratio * z_len

	assert(frustum.fov)
	return frustum
end

local function calc_csm_camera_bounding(view_camera, view_frustum, ratios)
	local frustum_desc = split_new_frustum(view_frustum, ratios)
	
	local _, _, vp = ms:view_proj(view_camera, frustum_desc, true)

	local frustum = mathbaselib.new_frustum(ms, vp)
	local points = frustum:points()	
	local bb = mathbaselib.new_bounding(ms)
	for _, v in pairs(points) do
		bb:append(v)
	end

	return bb
end

local function calc_csm_camera(view_camera, lightdir, ratios, camera_far)
	local bb = calc_csm_camera_bounding(view_camera, view_camera.frustum, ratios)
	local eyepos = bb:get "sphere"
	eyepos[4] = 1
	return {
		type = "csm_shadow",
		eyepos = eyepos,
		viewdir = lightdir,
		updir = {0, 1, 0, 0},
		frustum = {
			ortho = true,
			l = -1, r = 1,
			b = -1, t = 1,
			n = -camera_far, f = camera_far,
		},
	}
end

local function create_crop_matrix(shadow)
	local view_camera = camerautil.get_camera(world, "main_view")
	local bb = calc_csm_camera_bounding(nil, view_camera.frustum, shadow.csm.split_ratios)
	local aabb = bb:get "aabb"
	local min, max = aabb.min, aabb.max
	min[4], max[4] = 1, 1	-- as point

	local csm = shadow.csm
	local csmindex = csm.index
	local shadowcamera = camerautil.get_camera(world, "csm" .. csmindex)
	local _, proj = ms:view_proj(nil, shadowcamera.frustum)
	local minproj, maxproj = ms(min, proj, "%", max, proj, "%TT")

	local scalex, scaley = 2 / (maxproj[1] - minproj[1]), 2 / (maxproj[2] - minproj[2])
	if csm.stabilize then
		local quantizer = shadow.shadowmap_size
		scalex = quantizer / math.ceil(quantizer / scalex);
		scaley = quantizer / math.ceil(quantizer / scaley);
	end

	local function calc_offset(a, b, scale)
		return (a + b) * 0.5 * scale
	end

	local offsetx, offsety = 
		calc_offset(maxproj[1], minproj[1], scalex), 
		calc_offset(maxproj[2], minproj[2], scaley)

	if csm.stabilize then
		local half_size = shadow.shadowmap_size * 0.5;
		offsetx = math.ceil(offsetx * half_size) / half_size;
		offsety = math.ceil(offsety * half_size) / half_size;
	end
	
	return {
		scalex, 0, 0, 0,
		0, scaley, 0, 0,
		0, 0, 1, 0,
		offsetx, offsety, 0, 1,
	}
end

function maker_camera:update()
	local dl = world:first_entity "directional_light"
	local lightdir = ms(dl.rotation, "dnP")
	
	local maincamera = camerautil.get_camera(world, "main_view")

	for _, eid in world:each "shadow" do
		local shadowentity = world[eid]

		local shadowcamera = camerautil.get_camera(world, shadowentity.camera_tag)
		shadowcamera.viewdir(lightdir)
		local bb = calc_csm_camera_bounding(maincamera, maincamera.frustum, shadowentity.shadow.csm.split_ratios)
		local eyepos = bb:get "sphere"
		eyepos[4] = 1
		shadowcamera.eyepos(eyepos)
		shadowcamera.crop_matrix = create_crop_matrix(shadowentity.shadow)
	end
end

local sm = ecs.system "shadow_maker"
sm.depend "primitive_filter_system"
sm.depend "shadowmaker_camera"
sm.dependby "render_system"

local function create_csm_entity(view_camera, lightdir, index, ratios, shadowmap_size, camera_far)
	camera_far = camera_far or 10000
	local camera_tag = "csm" .. index
	camerautil.bind_camera(world, camera_tag, calc_csm_camera(view_camera, lightdir, ratios, camera_far))
	return world:create_entity {
		material = {
			{ref_path = fs.path "/pkg/ant.resources/depiction/materials/shadow/csm_cast.material"},
		},
		shadow = {
			shadowmap_size = shadowmap_size,
			bias = 0.003,
			depth_type = "linear",
			normal_offset = {0, 0, 0, 0},
			csm = {
				split_ratios = ratios,
				index = index,
				stabilize = true,
			}
		},
		viewid = viewidmgr.get "shadow_maker",
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
		name = "direction light shadow maker",
	}
end

function sm:post_init()
	local camera = camerautil.get_camera(world, "main_view")
	local d_light = world:first_entity "directional_light"
	local lightdir = ms(d_light.rotation, "dnT")
	local ratios = {
		{0, 0.15},
		{0.15, 0.35},
		{0.35, 0.65},
		{0.65, 1},
	}
	for ii=1, #ratios do
		local ratio = ratios[ii]
		create_csm_entity(camera, lightdir, ii, ratio, 1024, 1000)
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
	
		local shadowmat = sm.material
		replace_material(results.opaticy, 		shadowmat)
		replace_material(results.translucent, 	shadowmat)
	end
end

local debug_sm = ecs.system "debug_shadow_maker"
debug_sm.depend "shadow_maker"

function debug_sm:init()

end