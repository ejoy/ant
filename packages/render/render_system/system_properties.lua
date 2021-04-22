local ecs = ...
local world = ecs.world

local fbmgr		= require "framebuffer_mgr"
local math3d	= require "math3d"

local mc		= import_package "ant.math".constant
local iom		= world:interface "ant.objcontroller|obj_motion"
local ishadow	= world:interface "ant.render|ishadow"
local ilight	= world:interface "ant.render|light"
local itimer	= world:interface "ant.timer|timer"
local icamera	= world:interface "ant.camera|camera"

local m = ecs.interface "system_properties"
local function def_tex_prop(stage)
	return {stage=stage, texture={handle=nil}}
end

local function def_buffer_prop(stage)
	return {stage=stage, value=nil}
end

local system_properties = {
	--lighting
	u_eyepos				= math3d.ref(mc.ZERO_PT),
	u_cluster_size			= math3d.ref(mc.ZERO_PT),
	u_cluster_shading_param	= math3d.ref(mc.ZERO_PT),
	u_cluster_shading_param2= math3d.ref(mc.ZERO_PT),
	u_light_count			= math3d.ref(mc.ZERO_PT),
	b_light_grids			= def_buffer_prop(-1),
	b_light_index_lists		= def_buffer_prop(-1),
	b_light_info			= def_buffer_prop(-1),
	u_time					= math3d.ref(mc.ZERO_PT),
	--IBL
	s_irradiance			= def_tex_prop(5),
	s_prefilter				= def_tex_prop(6),
	s_LUT					= def_tex_prop(7),

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

	s_mainview_depth	= def_tex_prop(5),
	s_mainview			= def_tex_prop(6),
	s_shadowmap			= def_tex_prop(7),
	s_postprocess_input	= def_tex_prop(7),
}

function m.get(n)
	return system_properties[n]
end

local function get_sky_entity()
	local sky_eid
	for _, eid in world:each "skybox" do
		sky_eid = eid
	end

	for _, eid in world:each "procedural_sky" do
		sky_eid = eid
	end
	return sky_eid
end

local function update_lighting_properties()
	local mq = world:singleton_entity "main_queue"
	system_properties["u_eyepos"].id = iom.get_position(mq.camera_eid)

	system_properties["u_light_count"].v = {world:count "light_type", 0, 0, 0}

	local skyeid = get_sky_entity()
	if skyeid then
		local sky = world[skyeid]
		local ibl = sky._ibl
		system_properties["s_irradiance"].texture.handle= ibl.irradiance.handle
		system_properties["s_prefilter"].texture.handle	= ibl.prefilter.handle
		system_properties["s_LUT"].texture.handle		= ibl.LUT.handle
	end

	if ilight.use_cluster_shading() then
		local mc_eid = mq.camera_eid
		local vr = mq.render_target.view_rect
	
		local cs = world:singleton_entity "cluster_render"
		local cluster_size = cs.cluster_render.cluster_size
		system_properties["u_cluster_size"].v	= cluster_size
		local f = icamera.get_frustum(mc_eid)
		local near, far = f.n, f.f
		system_properties["u_cluster_shading_param"].v	= {vr.w, vr.h, near, far}
		local num_depth_slices = cluster_size[3]
		local log_farnear = math.log(far/near, 2)
		local log_near = math.log(near)
	
		system_properties["u_cluster_shading_param2"].v	= {
			num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear,
			vr.w / cluster_size[1], vr.h/cluster_size[2],
		}

		local cs_p = cs.cluster_render.properties
		local function update_buffer(name, ...)
			if name then
				local sp, p = system_properties[name], cs_p[name]
				sp.stage  = p.stage
				sp.handle = p.handle
				sp.access = p.access
				update_buffer(...)
			end
		end
		update_buffer("b_light_grids", "b_light_index_lists", "b_light_info")
	else
		local li = system_properties.b_light_info
		li.stage = 12
		li.handle = ilight.light_buffer()
		li.access = "r"
	end
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

local starttime = itimer.current()

local function update_timer_properties()
	local t = system_properties["u_time"]
	t.v = {itimer.current()-starttime, itimer.delta(), 0, 0}
end

function m.properties()
	return system_properties
end

function m.update()
	update_timer_properties()
	update_lighting_properties()
	update_shadow_properties()
	update_postprocess_properties()
end