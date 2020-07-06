local ecs = ...
local world = ecs.world

local computil  = world:interface "ant.render|entity"
local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local irender   = world:interface "ant.render|irender"
local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

local math3d    = require "math3d"

local icamera	= world:interface "ant.camera|camera"
local iom		= world:interface "ant.objcontroller|obj_motion"
local ilight	= world:interface "ant.render|light"
local ishadow	= world:interface "ant.render|ishadow"

local shadowdbg_sys = ecs.system "shadow_debug_system"

local quadsize = 192

local quadmaterial = "/pkg/ant.resources/materials/shadow/shadowmap_quad.material"

local function csm_shadow_debug_quad()
	local splitnum = ishadow.split_num()
	local fbidx = ishadow.fb_index()
	local fb = fbmgr.get(fbidx)

	local rect = {x=0, y=0, w=quadsize*splitnum, h=quadsize}
	local q_eid = computil.create_quad_entity(rect, quadmaterial, "csm_quad")
	ishadow.set_property(q_eid, "s_shadowmap", fbmgr.get_rb(fb[1]).handle)
end

local frustum_colors = {
	0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffff00,
}

function shadowdbg_sys:post_init()
	csm_shadow_debug_quad()
end

local function find_csm_entity(index)
	for _, seid in world:each "csm" do
		local se = world[seid]
		if se.csm.index == index then
			return seid
		end
	end
end

local function get_split_distance(index)
	local mq = world:singleton_entity "main_queue"
	local ff = ishadow.calc_split_frustums(icamera.get_frustum(mq.camera_eid))
	local f = ff[index]
	return f.n, f.f
end

local function create_debug_entity()
	for _, seid in world:each "shadow_debug" do
		world:remove_entity(seid)
	end

	for _, seid in world:each "csm" do
		local s = world[seid]
		local idx = s.csm.index
		local vp  = icamera.calc_viewproj(s.camera_eid)
		local frustum_points = math3d.frustum_points(vp)
		local color = frustum_colors[idx]

		computil.create_frustum_entity(frustum_points, "main view part" .. idx, color)
		computil.create_axis_entity(iom.srt(s.camera_eid), "csm_axis:" .. idx, color)
	end
end

local function print_points(points)
	for idx, p in ipairs(points) do
		print(string.format("\tpoint[%d]:[%s]", idx, math3d.tostring(p)))
	end
end

local blit_shadowmap_viewid = viewidmgr.generate "blit_shadowmap"

local function check_shadow_matrix()
	local csm1 = world[find_csm_entity(1)]
	local lightdir = iom.get_direction(ilight.directional_light())
	print("light direction:", math3d.tostring(lightdir))

	local mq = world:singleton_entity "main_queue"
	print("eye posision:", math3d.tostring(iom.get_position(mq.camera_eid)))
	print("view direction:", math3d.tostring(iom.get_direction(mq.camera_eid)))

	local camera_2_origin = math3d.length(iom.get_position(mq.camera_eid))
	print("check eye position to [0, 0, 0] distance:", camera_2_origin)

	local dis_n, dis_f = get_split_distance(1)
	print("csm1 distance:", dis_n, dis_f)

	if dis_n <= camera_2_origin and camera_2_origin <= dis_f then
		print("origin is on csm1")
	else
		print("origin is not on csm1")
	end

	local ff = ishadow.calc_split_frustums(icamera.get_frustum(mq.camera_eid))
	local split_frustum_desc = ff[csm1.index]
	local viewmat = icamera.calc_viewmat(mq.camera_eid)
	local vp = math3d.mul(math3d.projmat(split_frustum_desc), viewmat)

	local frustum_points = math3d.frusutm_points(vp)
	local center = math3d.frustum_center(frustum_points)

	print("view split frusutm corners, center: " .. math3d.tostring(center))
	print_points(frustum_points)

	local lightmatrix = math3d.lookto(center, lightdir)
	local corners_LS = {}
	for _, c in ipairs(frustum_points) do
		corners_LS[#corners_LS+1] = math3d.transform(lightmatrix, c, 1)
	end

	local minextent, maxextent = math3d.minmax(corners_LS)

	print("light space corner points:")
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

	local newvp = math3d.mul(math3d.projmat(frustum_desc), math3d.lookto(center, lightdir))
	local new_light_frustum_points = math3d.frustum_points(newvp)
	computil.create_frustum_entity(new_light_frustum_points, "lua calc view frustum",  0xff0000ff)

	---------------------------------------------------------------------------------------------------------

	print("shadow camera view direction:", math3d.tostring(iom.get_direction(csm1.camera_eid)))
	print("shadow camera position:", math3d.string(iom.get_position(csm1.camera_eid)))

	local shadowcamera_frustum_desc = icamera.get_frustum(csm1.camera_eid)
	print(string.format("shadow camera frustum:[l=%f, r=%f, b=%f, t=%f, n=%f, f=%f]", 
		shadowcamera_frustum_desc.l, shadowcamera_frustum_desc.r, 
		shadowcamera_frustum_desc.b, shadowcamera_frustum_desc.t, 
		shadowcamera_frustum_desc.n, shadowcamera_frustum_desc.f))

	local shadow_viewproj = icamera.calc_viewproj(csm1.camera_eid)
	local shadowcamera_frustum_points = math3d.frustum_points(shadow_viewproj)

	print("shadow view frustm point")
	print_points(shadowcamera_frustum_points)
	computil.create_frustum_entity(shadowcamera_frustum_points, "view frustum", 0xffffff00)

	-------------------------------------------------------------------------------------------------
	-- test shadow matrix
	local pt = {-0.00009, -0.01307, 0.1544} --mc.T_ZERO_PT
	local worldmat = {
		0.0, 0.0, -20.02002, -20,
	}
	local origin_CS = math3d.totable(shadow_viewproj.t)
	print(string.format("origin clip space:[%f, %f, %f, %f]", origin_CS[1], origin_CS[2], origin_CS[3], origin_CS[4]))
	local origin_NDC = {
		origin_CS[1] / origin_CS[4], 
		origin_CS[2] / origin_CS[4], 
		origin_CS[3] / origin_CS[4], 
		origin_CS[4] / origin_CS[4]
	}
	print(string.format("origin ndc space:[%f, %f, %f, %f]", origin_NDC[1], origin_NDC[2], origin_NDC[3], origin_NDC[4]))
	local cp_mat = ishadow.crop_matrices()[csm1.index]
	local shadow_matrix = math3d.mul(cp_mat, shadow_viewproj)
	local origin_CS_With_Crop = math3d.transform(shadow_matrix, {0, 0, 0.55, 1})
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
	if ishadow.depth_type() == "linear" then
		local size = csm1.shadow.shadowmap_size
		local fb = fbmgr.get(csm1.render_target.fb_idx)
		local memory_handle, width, height, pitch = irender.read_render_buffer_content({w=size,h=size}, "RGBA8", fb[1], true)

		local depth = pt[3]
		local x, y = pt[1], pt[2]
		local fx, fy = math.floor(x * width), math.floor(y * height)
		local cx, cy = math.ceil(x * width), math.ceil(y * height)

		local depth0 = memory_handle[fy*pitch+fx]
		local depth1 = memory_handle[fy*pitch+cx]

		local depth2 = memory_handle[cy*pitch+fx]
		local depth3 = memory_handle[cy*pitch+cx]

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

local function log_split_distance()
	for i=1, 4 do
		local n, f = get_split_distance(i)
		print(string.format("csm%d, distance[%f, %f]", i, n, f))
	end
end

local record_camera_state_mb = world:sub {"record_camera_state"}

function shadowdbg_sys:data_changed()
	for _, eid in record_camera_state_mb:unpack() do
		log_split_distance()
		create_debug_entity()

		check_shadow_matrix()
	end
end
