local ecs = ...
local world = ecs.world
local renderpkg = import_package "ant.render"
local fbmgr = renderpkg.fbmgr
local camerautil = renderpkg.camera
local shadowutil = renderpkg.shadow

local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local math3d = require "math3d"

ecs.component "render_properties"
	.lighting "properties"
	.shadow "properties"
	.postprocess "properties"

ecs.singleton "render_properties" {
	lighting = {
		uniforms = {
			directional_lightdir 	= {type="v4", 	name="Direction Light", 		value=mc.T_ZERO},
			directional_color 		= {type="color",name="Direction Color", 		value=mc.T_ZERO},
			directional_intensity 	= {type="v4", 	name = "Direction Intensity", 	value=mc.T_ZERO},

			ambient_mode 		= {type="v4", 	 name ="ambient_mode", 			value=mc.T_ZERO},
			ambient_skycolor 	= {type="color", name ="ambient_skycolor", 		value=mc.T_ZERO},
			ambient_midcolor 	= {type="color", name ="ambient_midcolor",		value=mc.T_ZERO},
			ambient_groundcolor = {type="color", name ="ambient_groundcolor", 	value=mc.T_ZERO},

			u_eyepos			= {type="v4", name="eye position", value=mc.T_ZERO_PT},
		},
		textures = {},
	},
	shadow = {
		uniforms = {
			u_csm_matrix 			= {type="m4_array", name="csm_matrices", value_array={mc.T_IDENTITY_MAT, mc.T_IDENTITY_MAT, mc.T_IDENTITY_MAT, mc.T_IDENTITY_MAT}},
			u_csm_split_distances	= {type="v4", name="csm_split_distances", value=mc.T_ZERO},

			u_depth_scale_offset	= {type="v4", name="depth_scale_offset", value=mc.T_ZERO},
			u_shadow_param1			= {type="v4", name="shadow_param1(bais, normal_offset, shadowmap_texelsize, 0)", value=mc.T_ZERO},
			u_shadow_param2			= {type="v4", name="shadow_param2(shadowcolor.xyz, 0)", value=mc.T_ZERO},
		},
		textures = {
			s_shadowmap = {type="texture", name="csm_shadowmap", },
		},
	},
	postprocess = {
		uniforms = {},
		textures = {
			s_mainview = {type="texture", name="main_queue backbuffer", },
		},
	},
}

local function add_directional_light_properties(world, uniform_properties)
	local dlight = world:singleton_entity "directional_light"
	if dlight then
		uniform_properties["directional_lightdir"].value.v 	= dlight.direction
		uniform_properties["directional_color"].value.v 	= dlight.directional_light.color
		uniform_properties["directional_intensity"].value.v = {dlight.directional_light.intensity, 0.28, 0, 0}
	end
end

local mode_type = {
	factor = 0,
	color = 1,
	gradient = 2,
}

--add ambient properties
local function add_ambient_light_propertices(world, uniform_properties)
	local le = world:singleton_entity "ambient_light"
	if le then
		local ambient = le.ambient_light
		uniform_properties["ambient_mode"].value.v			= {mode_type[ambient.mode], ambient.factor, 0, 0}
		uniform_properties["ambient_skycolor"].value.v		= ambient.skycolor
		uniform_properties["ambient_midcolor"].value.v		= ambient.midcolor
		uniform_properties["ambient_groundcolor"].value.v	= ambient.groundcolor
	end
end 

local function load_lighting_properties(world, render_properties)
	local lighting_properties = assert(render_properties.lighting.uniforms)

	add_directional_light_properties(world, lighting_properties)
	add_ambient_light_propertices(world, lighting_properties)

	local camera = camerautil.main_queue_camera(world)
	lighting_properties["u_eyepos"].value.v = camera.eyepos
end

local function calc_viewport_crop_matrix(csm_idx)
	local ratios = shadowutil.get_split_ratios()
	local numsplit = #ratios
	local spiltunit = 1 / numsplit

	local offset = spiltunit * (csm_idx - 1)

	return math3d.matrix(
		spiltunit, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0, 
		0.0, 0.0, 1.0, 0.0,
		offset, 0.0, 0.0, 1.0)
end

local function load_shadow_properties(world, render_properties)
	local shadow_properties = render_properties.shadow
	local uniforms, textures = shadow_properties.uniforms, shadow_properties.textures

	--TODO: shadow matrix consist of lighting matrix, crop matrix and viewport offset matrix
	-- but crop matrix and viewport offset matrix only depend csm split ratios
	-- we can detect csm split ratios changed, and update those matrix two matrices, and combine as bias matrix
	local csm_matrixs = uniforms.u_csm_matrix.value_array
	local split_distances = {0, 0, 0, 0}
	for _, eid in world:each "csm" do
		local se = world[eid]
		local csm = se.csm

		local camera = world[se.camera_eid].camera

		local idx = csm.index
		local split_distanceVS = csm.split_distance_VS
		if split_distanceVS then
			split_distances[idx] = split_distanceVS
			local vp = mu.view_proj(camera)
			vp = math3d.mul(shadowutil.shadow_crop_matrix(), vp)
			local viewport_cropmatrix = calc_viewport_crop_matrix(idx)
			local m = assert(csm_matrixs[csm.index])
			m.m = math3d.mul(viewport_cropmatrix, vp)
		end
	end

	uniforms["u_csm_split_distances"].value.v = split_distances

	local shadowentity = world:singleton_entity "shadow"
	if shadowentity then
		local fb = fbmgr.get(shadowentity.fb_index)
		local sm = textures["s_shadowmap"]
		sm.stage = world:interface "ant.render|uniforms".system_uniform("s_shadowmap").stage
		sm.handle = fbmgr.get_rb(fb[1]).handle

		uniforms["u_depth_scale_offset"].value.v = shadowutil.shadow_depth_scale_offset()
		local shadow = shadowentity.shadow
		uniforms["u_shadow_param1"].value.v = {shadow.bias, shadow.normal_offset, 1/shadow.shadowmap_size, 0}
		local shadowcolor = shadow.color or {0, 0, 0, 0}
		uniforms["u_shadow_param2"].value.v = shadowcolor
	end
end

local function load_postprocess_properties(world, render_properties)
	local mq = assert(world:singleton_entity "main_queue")
	local postprocess = render_properties.postprocess
	local fbidx = mq.render_target.fb_idx
	if fbidx then
		local fb = fbmgr.get(fbidx)
		local rendertex = fbmgr.get_rb(fb[1]).handle
		local mainview_name = "s_mainview"
		local stage = assert(world:interface "ant.render|uniforms".system_uniform(mainview_name)).stage
		local mv = postprocess.textures[mainview_name]
		mv.stage = stage
		mv.handle = rendertex
	end
end

local load_properties_sys = ecs.system "load_properties"
load_properties_sys.require_singleton "render_properties"
load_properties_sys.require_interface "ant.render|uniforms"

function load_properties_sys:load_render_properties()
	local rp = world:singleton "render_properties"
	load_lighting_properties(world, rp)
	load_shadow_properties(world, rp)
	load_postprocess_properties(world, rp)
end
