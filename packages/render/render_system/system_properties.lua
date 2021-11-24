local ecs = ...
local world = ecs.world
local w = world.w
local fbmgr		= require "framebuffer_mgr"
local sampler = require "sampler"
local math3d	= require "math3d"
local bgfx		= require "bgfx"


local mc		= import_package "ant.math".constant
local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"
local ishadow	= ecs.import.interface "ant.render|ishadow"
local ilight	= ecs.import.interface "ant.render|ilight"
local itimer	= ecs.import.interface "ant.timer|itimer"
local icamera	= ecs.import.interface "ant.camera|icamera"
local iibl		= ecs.import.interface "ant.render.ibl|iibl"
local isp = ecs.interface "isystem_properties"

local flags = sampler.sampler_flag {
	MIN="LINEAR",
	MAG="LINEAR",
	U="CLAMP",
	V="CLAMP",
}
local def_cubetex_handle = bgfx.create_texturecube(1, false, 1, "RGBA8", flags)
local def_2dtex_handle = bgfx.create_texture2d(1, 1, false, 1, "RGBA8", flags)

local function def_tex_prop(stage, handle)
	return {stage=stage, texture={handle=handle}}
end

local function def_buffer_prop(stage)
	return {stage=stage, value=nil}
end

local def_ibl = {
	irradiance = {handle = def_cubetex_handle},
	prefilter = {handle = def_cubetex_handle, mipmap_count = 0},
	LUT = {handle = def_2dtex_handle},
	intensity = 0
}

local enable_ibl = true

local system_properties = {
	--camera
	u_eyepos				= math3d.ref(mc.ZERO_PT),
	u_exposure_param		= math3d.ref(math3d.vector(16.0, 0.008, 100.0, 0.0)),	--
	u_camera_param			= math3d.ref(mc.ZERO),
	--lighting
	u_cluster_size			= math3d.ref(mc.ZERO),
	u_cluster_shading_param	= math3d.ref(mc.ZERO),
	u_light_count			= math3d.ref(mc.ZERO),
	b_light_grids			= def_buffer_prop(-1),
	b_light_index_lists		= def_buffer_prop(-1),
	b_light_info			= def_buffer_prop(-1),
	u_time					= math3d.ref(mc.ZERO),

	--IBL
	u_ibl_param				= math3d.ref(mc.ZERO),
	s_irradiance			= def_tex_prop(5, def_cubetex_handle),
	s_prefilter				= def_tex_prop(6, def_cubetex_handle),
	s_LUT					= def_tex_prop(7, def_2dtex_handle),

	-- shadow
	--   csm
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
	s_shadowmap			= def_tex_prop(8),

	--   omni
	u_omni_matrix = {
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
		math3d.ref(mc.IDENTITY_MAT),
	},

	u_tetra_normal_Green	= {math3d.ref(mc.ZERO),},
	u_tetra_normal_Yellow	= {math3d.ref(mc.ZERO),},
	u_tetra_normal_Blue		= {math3d.ref(mc.ZERO),},
	u_tetra_normal_Red		= {math3d.ref(mc.ZERO),},

	s_omni_shadowmap		= def_tex_prop(9),
}

function isp.get(n)
	return system_properties[n]
end

local function get_ibl()
	if not enable_ibl then
		return def_ibl
	end
	local ibl = iibl.get_ibl()
	return ibl.irradiance.handle and ibl or def_ibl
end

local function main_camera_ref()
	local v = w:singleton("main_queue", "camera_ref:in")
	return v.camera_ref
end

local function main_render_target()
	local v = w:singleton("main_queue", "render_target:in")
	return v.render_target
end

local function update_cluster_render_properties(vr, near, far)
	local cr = w:object("cluster_render", 1)
	local cluster_size = cr.cluster_size
	system_properties["u_cluster_size"].v	= cluster_size
	local num_depth_slices = cluster_size[3]
	local log_farnear = math.log(far/near, 2)
	local log_near = math.log(near, 2)

	system_properties["u_cluster_shading_param"].v	= {
		num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear,
		vr.w / cluster_size[1], vr.h/cluster_size[2],
	}

	local cs_p = cr.properties
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
end


local function update_lighting_properties(viewrect, camerapos, near, far)
	system_properties["u_eyepos"].id = camerapos
	local cp = system_properties["u_camera_param"]
	cp.v = math3d.set_index(cp, 1, near, far)
	local nl = ilight.count_visible_light()
	system_properties["u_light_count"].v = {nl, 0, 0, 0}

	local function update_ibl_tex(ibl)
		system_properties["s_irradiance"].texture.handle= ibl.irradiance.handle
		system_properties["s_prefilter"].texture.handle	= ibl.prefilter.handle
		system_properties["s_LUT"].texture.handle		= ibl.LUT.handle
		local ip = system_properties["u_ibl_param"]
		ip.v = math3d.set_index(ip, 1, ibl.prefilter.mipmap_count, ibl.intensity)
	end
	--TODO: this setting only do when ibl is change
	update_ibl_tex(get_ibl())

	if ilight.use_cluster_shading() then
		update_cluster_render_properties(viewrect, near, far)
	else
		local li = system_properties.b_light_info
		li.stage = 12
		li.handle = ilight.light_buffer()
		li.access = "r"
	end
end

isp.update_lighting_properties = update_lighting_properties

local function update_csm_properties()
	local csm_matrixs = system_properties.u_csm_matrix
	local split_distances = {0, 0, 0, 0}
	for v in w:select "csm_queue visible csm:in camera_ref:in" do
		local csm = v.csm

		local idx = csm.index
		local split_distanceVS = csm.split_distance_VS
		if split_distanceVS then
			split_distances[idx] = split_distanceVS
			local camera = icamera.find_camera(v.camera_ref)
			csm_matrixs[csm.index].id = math3d.mul(ishadow.crop_matrix(idx), camera.viewprojmat)
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

local function update_omni_shadow_properties()
	-- local ios = ecs.import.interface "ant.render|iomni_shadow"
	-- local s = ios.setting()
	-- system_properties["s_omni_shadowmap"].texture.handle = ios.fb_index()

	-- --TODO: need put this info to cluster shading framework, only support 4 point light shadow
	-- system_properties["u_omni_param"] = {4, 0, 0, 0}


end

local function update_shadow_properties()
	update_csm_properties()
	update_omni_shadow_properties()
end

local starttime = itimer.current()

local function update_timer_properties()
	local t = system_properties["u_time"]
	local timepassed = itimer.current()-starttime
	t.v = math3d.set_index(t, 1, timepassed*0.001, itimer.delta()*0.001)
end

function isp.properties()
	return system_properties
end

function isp.update()
	update_timer_properties()
	local cameraref = main_camera_ref()
	local camerapos = iom.get_position(cameraref)
	local f = icamera.get_frustum(cameraref)
	local mainrt = main_render_target()
	update_lighting_properties(mainrt.view_rect, camerapos, f.n, f.f)
	update_shadow_properties()
end

function isp.enable_ibl(enable)
	enable_ibl = enable
end