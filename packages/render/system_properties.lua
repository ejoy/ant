local ecs = ...
local world = ecs.world

local fbmgr = require "framebuffer_mgr"

local mc = import_package "ant.math".constant

local math3d = require "math3d"
local iom = world:interface "ant.objcontroller|obj_motion"
local ilight = world:interface "ant.render|light"
local ishadow = world:interface "ant.render|ishadow"

local m = ecs.interface "system_properties"
local system_properties = {
	--lighting
	u_directional_lightdir	= math3d.ref(mc.ZERO),
	u_directional_color		= math3d.ref(mc.ZERO),
	u_directional_intensity	= math3d.ref(mc.ZERO),
	u_eyepos				= math3d.ref(mc.ZERO_PT),

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
	local deid = ilight.directional_light()
	if deid then
		local data = ilight.data(deid)
		system_properties["u_directional_lightdir"].v	= math3d.inverse(iom.get_direction(deid))
		system_properties["u_directional_color"].v		= data.color
		system_properties["u_directional_intensity"].v	= data.intensity
	end
end

local function update_lighting_properties()
	add_directional_light_properties()

	local mq = world:singleton_entity "main_queue"
	system_properties["u_eyepos"].id = iom.get_position(mq.camera_eid)
end

local function update_shadow_properties()
	local csm_matrixs = system_properties.u_csm_matrix
	local split_distances = {0, 0, 0, 0}
	for _, eid in world:each "csm" do
		local se = world[eid]
		if se.visible then
			local csm = se.csm

			local idx = csm.index
			local split_distanceVS = csm.split_distance_VS
			if split_distanceVS then
				split_distances[idx] = split_distanceVS
				local rc = world[se.camera_eid]._rendercache
				csm_matrixs[csm.index].id = math3d.mul(ishadow.crop_matrix(idx), rc.viewprojmat)
			end
		end
	end

	system_properties["u_csm_split_distances"].v = split_distances

	local fb = fbmgr.get(ishadow.fb_index())
	local sm = system_properties["s_shadowmap"]
	sm.texture.handle = fbmgr.get_rb(fb[1]).handle

	if ishadow.depth_type() == "linear" then
		system_properties["u_depth_scale_offset"].id = ishadow.shadow_depth_scale_offset()
	end

	system_properties["u_shadow_param1"].v = ishadow.shadow_param()
	system_properties["u_shadow_param2"].v = ishadow.color()
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

function m.update()
	update_lighting_properties()
	update_shadow_properties()
	update_postprocess_properties()
end