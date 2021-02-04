local ecs = ...
local world = ecs.world

local fbmgr		= require "framebuffer_mgr"
local math3d	= require "math3d"
local bgfx		= require "bgfx"

local mc		= import_package "ant.math".constant
local iom		= world:interface "ant.objcontroller|obj_motion"
local ilight	= world:interface "ant.render|light"
local ishadow	= world:interface "ant.render|ishadow"

local m = ecs.interface "system_properties"
local system_properties = {
	--lighting
	-- u_directional_lightdir	= math3d.ref(mc.ZERO),
	-- u_directional_color		= math3d.ref(mc.ZERO),
	-- u_directional_intensity	= math3d.ref(mc.ZERO),
	u_eyepos				= math3d.ref(mc.ZERO_PT),
	u_numlight				= math3d.ref(mc.ZERO_PT),

	-- u_light_pos				= {
	-- 	math3d.ref(mc.ZERO_PT),
	-- 	math3d.ref(mc.ZERO_PT),
	-- 	math3d.ref(mc.ZERO_PT),
	-- 	math3d.ref(mc.ZERO_PT),
	-- },
	-- u_light_color			= {
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- },
	-- u_light_dir				= {
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- },
	-- u_light_param			= {
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- 	math3d.ref(mc.ZERO),
	-- },

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

	s_mainview_depth	= {stage=5, texture={handle=nil}},
	s_mainview			= {stage=6, texture={handle=nil}},
	s_shadowmap			= {stage=7, texture={handle=nil}},
	s_postprocess_input	= {stage=7, texture={handle=nil}},
}

function m.get(n)
	return system_properties[n]
end

-- local function add_directional_light_properties()
-- 	local deid = ilight.directional_light()
-- 	if deid then
-- 		local data = ilight.data(deid)
-- 		system_properties["u_directional_lightdir"].v	= math3d.inverse(iom.get_direction(deid))
-- 		system_properties["u_directional_color"].v		= data.color
-- 		system_properties["u_directional_intensity"].v	= data.intensity
-- 	else
-- 		system_properties["u_directional_lightdir"].v	= mc.ZERO
-- 		system_properties["u_directional_color"].v		= mc.ZERO
-- 		system_properties["u_directional_intensity"].v	= mc.ZERO
-- 	end
-- end

-- local function add_point_light_properties()
-- 	local numlight = 1
-- 	local maxlight<const> = ilight.max_point_light()
-- 	for _, leid in world:each "light_type" do
-- 		if numlight <= maxlight then
-- 			local e = world[leid]
-- 			local lt = e.light_type
-- 			if lt == "point" or lt == "spot" then
-- 				system_properties.u_light_color[numlight].v = ilight.color(leid)
-- 				local param = {0.0, 0.0, 0.0, 0.0}
-- 				local lightdir = system_properties.u_light_dir[numlight]
-- 				if lt == "spot" then
-- 					lightdir.v = iom.get_direction(leid)
-- 					param[1] = 2.0
-- 					local radian = ilight.radian(leid) * 0.5
-- 					local outer_radian = radian * 1.1
-- 					param[2], param[3] = math.cos(radian), math.cos(outer_radian)
-- 				else
-- 					lightdir.v = mc.ZERO
-- 				end

-- 				system_properties.u_light_pos[numlight].v	= iom.get_position(leid)
-- 				system_properties.u_light_param[numlight].v = param
-- 			end

-- 			numlight = numlight + 1
-- 		end
-- 	end

-- 	for i=numlight, maxlight-numlight do
-- 		system_properties.u_light_color[i].v	= mc.ZERO
-- 		system_properties.u_light_pos[i].v		= mc.ZERO
-- 		system_properties.u_light_dir[i].v		= mc.ZERO
-- 		system_properties.u_light_param[i].v	= mc.ZERO
-- 	end
-- 	if numlight > maxlight then
-- 		log.warn("point light number exceed, max point/spot light: %d", maxlight)
-- 	end
-- end

local lighttypes = {
	directional = 0,
	point = 1,
	spot = 2,
}

local function add_light_properties()
	--[[
		struct Light{
			vec4	pos;
			vec4	dir;
			vec4	color;
			float	type;
			float	intensity;
			float	inner_cutoff;
			float	outter_cutoff;
		};
	]]

	local lights = {}
	for _, leid in world:each "light_type" do
		local le = world[leid]
		
		local p	= math3d.tovalue(iom.get_position(leid))
		local d	= math3d.tovalue(iom.get_direction(leid))
		local c = ilight.color(leid)
		local t	= le.light_type
		lights[#lights+1] = ('f'):rep(16):pack(
			p[1], p[2], p[3], 1,
			d[1], d[2], d[3], 0,
			c[1], c[2], c[3], c[4],
			lighttypes[t], ilight.intensity(leid),
			ilight.inner_cutoff(leid),	ilight.outter_cutoff(leid))
	end
	local c = table.concat(lights, "")
	bgfx.update(ilight.light_buffer().handle, 0, bgfx.memory_buffer(c))
	system_properties["u_numlight"].v = math3d.vector(#lights, 0, 0, 0)
end

local function update_lighting_properties()
	add_light_properties()

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
	local fb = fbmgr.get(fbidx)

	local mv = system_properties["s_mainview"]
	mv.texture.handle = fbmgr.get_rb(fb[1]).handle

	local mvd = system_properties["s_mainview_depth"]
	mvd.texture.handle = fbmgr.get_rb(fb[#fb]).handle
end

function m.update()
	update_lighting_properties()
	update_shadow_properties()
	update_postprocess_properties()
end