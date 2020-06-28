local ecs = ...
local world = ecs.world
local renderpkg = import_package "ant.render"
local fbmgr = renderpkg.fbmgr
local shadowutil = renderpkg.shadow

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local math3d = require "math3d"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"

local m = ecs.interface "system_properties"
local system_properties = {
	--lighting
	directional_lightdir= math3d.ref(mc.ZERO),
	directional_color 	= math3d.ref(mc.ZERO),
	directional_intensity= math3d.ref(mc.ZERO),
	ambient_mode 		= math3d.ref(mc.ZERO),
	ambient_skycolor 	= math3d.ref(mc.ZERO),
	ambient_midcolor 	= math3d.ref(mc.ZERO),
	ambient_groundcolor = math3d.ref(mc.ZERO),
	u_eyepos			= math3d.ref(mc.ZERO_PT),

	-- shadow
	u_csm_matrix 		= {
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
	},
	u_csm_split_distances= math3d.ref(mc.ZERO),
	u_depth_scale_offset= math3d.ref(mc.ZERO),
	u_shadow_param1		= math3d.ref(mc.ZERO),
	u_shadow_param2		= math3d.ref(mc.ZERO),

	s_mainview			= {stage=6, texture={handle=nil}},
	s_shadowmap			= {stage=7, texture={handle=nil}},
	s_postprocess_input	= {stage=7, texture={handle=nil}},
}

function m.get(n)
	return system_properties[n]
end

local function add_directional_light_properties()
	local dlight = world:singleton_entity "directional_light"
	if dlight then
		system_properties["directional_lightdir"].v 	= dlight.direction
		system_properties["directional_color"].v 	= dlight.directional_light.color
		system_properties["directional_intensity"].v = {dlight.directional_light.intensity, 0.28, 0, 0}
	end
end

local mode_type = {
	factor = 0,
	color = 1,
	gradient = 2,
}

--add ambient properties
local function add_ambient_light_propertices()
	local le = world:singleton_entity "ambient_light"
	if le then
		local ambient = le.ambient_light
		system_properties["ambient_mode"].v			= {mode_type[ambient.mode], ambient.factor, 0, 0}
		system_properties["ambient_skycolor"].v		= ambient.skycolor
		system_properties["ambient_midcolor"].v		= ambient.midcolor
		system_properties["ambient_groundcolor"].v	= ambient.groundcolor
	end
end 

local function update_lighting_properties()
	add_directional_light_properties()
	add_ambient_light_propertices()

	local mq = world:singleton_entity "main_queue"
	system_properties["u_eyepos"].v = iom.get_position(mq.camera_eid)
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

local function update_shadow_properties()
	--TODO: shadow matrix consist of lighting matrix, crop matrix and viewport offset matrix
	-- but crop matrix and viewport offset matrix only depend csm split ratios
	-- we can detect csm split ratios changed, and update those matrix two matrices, and combine as bias matrix
	local csm_matrixs = system_properties.u_csm_matrix
	local split_distances = {0, 0, 0, 0}
	for _, eid in world:each "csm" do
		local se = world[eid]
		local csm = se.csm

		local idx = csm.index
		local split_distanceVS = csm.split_distance_VS
		if split_distanceVS then
			split_distances[idx] = split_distanceVS
			local vp = icamera.viewproj(se.camera_eid)
			vp = math3d.mul(shadowutil.shadow_crop_matrix(), vp)
			local viewport_cropmatrix = calc_viewport_crop_matrix(idx)
			csm_matrixs[csm.index].m = math3d.mul(viewport_cropmatrix, vp)
		end
	end

	system_properties["u_csm_split_distances"].v = split_distances

	local shadowentity = world:singleton_entity "shadow"
	if shadowentity then
		local fb = fbmgr.get(shadowentity.fb_index)
		local sm = system_properties["s_shadowmap"]
		sm.texture.handle = fbmgr.get_rb(fb[1]).handle

		system_properties["u_depth_scale_offset"].v = shadowutil.shadow_depth_scale_offset()
		local shadow = shadowentity.shadow
		system_properties["u_shadow_param1"].v = {shadow.bias, shadow.normal_offset, 1/shadow.shadowmap_size, 0}
		local shadowcolor = shadow.color or {0, 0, 0, 0}
		system_properties["u_shadow_param2"].v = shadowcolor
	end
end

local function update_postprocess_properties()
	local mq = world:singleton_entity "main_queue"
	local fbidx = mq.render_target.fb_idx
	if fbidx then
		local fb = fbmgr.get(fbidx)
		local mainview_name = "s_mainview"
		local mv = system_properties[mainview_name]
		mv.texture.handle = fbmgr.get_rb(fb[1]).handle
	end
end

local usp = ecs.system "update_system_properties"

function usp:update_system_properties()
	update_lighting_properties()
	update_shadow_properties()
	update_postprocess_properties()
end