local ecs = ...
local world = ecs.world

local computil = world:interface "ant.render|entity"
local camerautil= require "camera.util"
local shadowutil= require "shadow.util"
local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local uniforms  = world:interface "ant.render|uniforms"
local irender	= world:interface "ant.render|irender"
local mathpkg   = import_package "ant.math"
local mu, mc= mathpkg.util, mathpkg.constant
local math3d	= require "math3d"

local assetmgr = import_package "ant.asset"

----------------------------------------------------------------------------------------------------------
local dbg_sm_sys = ecs.system "debug_shadow_maker_system"


local quadsize = 192

local function csm_shadow_debug_quad()
	local smstage = uniforms.system_uniform("s_shadowmap").stage
	local quadmaterial = "/pkg/ant.resources/materials/shadow/shadowmap_quad.material"

	local se = world:singleton_entity "shadow"
	local fb = fbmgr.get(se.fb_index)

	local num_split = se.shadow.split.num_split
	local rect = {x=0, y=0, w=quadsize*num_split, h=quadsize}
	local q_eid = computil.create_quad_entity(rect, quadmaterial, "csm_quad")
	local qe = world[q_eid]

	--TODO
	assert(false, "can not patch anymore")
	-- local m = assetmgr.patch(qe.material, {})
	-- m.properties = {
	-- 	s_shadowmap = {
	-- 		stage = smstage,
	-- 		texture = {handle=fbmgr.get_rb(fb[1]).handle},
	-- 	}
	-- }
	-- qe.material = m
end

local frustum_colors = {
	0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffff00,
}

local function add_shadow_debug_policy(eid)
	world:add_policy(eid, {
		policy = {
			"ant.render|shadow_debug_policy",
		},
		data = {
			shadow_debug = true,
		}
	})
end

local function	csm_shadow_debug_frustum()
	for _, seid in world:each "csm" do
		local e = world[seid]
		local camera = world[e.camera_eid].camera
		local vp = mu.view_proj(camera)

		local color = frustum_colors[e.csm.index]
		local frustum_points = math3d.frustum_points(vp)
		
		add_shadow_debug_policy(
			computil.create_frustum_entity(frustum_points, "csm frusutm part" .. e.csm.index, color)
		)
		add_shadow_debug_policy(
			computil.create_axis_entity(
			{
				r=math3d.tovalue(math3d.torotation(camera.viewdir)), 
				t=math3d.tovalue(camera.eyepos)
			},
			color)
		)

	end
end

local function main_view_debug_frustum()
	local camera = camerautil.main_queue_camera(world)

	for _, seid in world:each "csm" do
		local s = world[seid]

		local csm = s.csm
		local vp = mu.view_proj(camera)
		local frustum_points = math3d.frustum_points(vp)
		add_shadow_debug_policy(
		computil.create_frustum_entity(frustum_points, "main view part" .. csm.index, frustum_colors[csm.index]))
	end
end

function dbg_sm_sys:post_init()
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
	local se = world[find_csm_entity(index)]

	local viewcamera = camerautil.main_queue_camera(world)
	local viewdistance = viewcamera.frustum.f - viewcamera.frustum.n

	local ratios = se.csm.split_ratios
	local n = viewcamera.frustum.n + ratios[1] * viewdistance
	local f = viewcamera.frustum.n + ratios[2] * viewdistance
	return n, f
end

local function create_debug_entity()
	for _, seid in world:each "shadow_debug" do
		world:remove_entity(seid)
	end

	main_view_debug_frustum()
	csm_shadow_debug_frustum()
end

local function print_points(points)
	for idx, p in ipairs(points) do
		print(string.format("\tpoint[%d]:[%s]", idx, math3d.tostring(p)))
	end
end

local function print_frustum_points(frustum_points)
	print_points(frustum_points)
end

local blit_shadowmap_viewid = viewidmgr.generate "blit_shadowmap"

local function check_shadow_matrix()
	local csm1 = world[find_csm_entity(1)]

	local lightdir = math3d.inverse(world:singleton_entity "directional_light".direction)
	print("light direction:", math3d.tostring(lightdir))

	local viewcamera = camerautil.main_queue_camera(world)
	print("eye posision:", math3d.tostring(viewcamera.eyepos))
	print("view direction:", math3d.tostring(viewcamera.viewdir))

	local camera_2_origin = math3d.length(viewcamera.eyepos)
	print("check eye position to [0, 0, 0] distance:", camera_2_origin)

	local dis_n, dis_f = get_split_distance(1)
	print("csm1 distance:", dis_n, dis_f)

	if dis_n <= camera_2_origin and camera_2_origin <= dis_f then
		print("origin is on csm1")
	else
		print("origin is not on csm1")
	end

	local split_frustum_desc = shadowutil.split_new_frustum(viewcamera.frustum, csm1.csm.split_ratios)
	local vp = mu.view_proj(viewcamera, split_frustum_desc)

	local frustum_points = math3d.frusutm_points(vp)
	local center = math3d.frustum_center(frustum_points)

	print(string.format("view split frusutm corners, center:[%f, %f, %f]", center[1], center[2], center[3]))
	print_frustum_points(frustum_points)

	local lightmatrix = math3d.lookto(center, lightdir)
	local corners_LS = {}
	local minextent, maxextent = {}, {}
	for _, c in ipairs(frustum_points) do
		local c_LS = math3d.transform(lightmatrix, c, 1)
		corners_LS[#corners_LS+1] = c_LS
		minextent[1] = minextent[1] and math.min(minextent[1], c_LS[1]) or c_LS[1]
		minextent[2] = minextent[2] and math.min(minextent[2], c_LS[2]) or c_LS[2]
		minextent[3] = minextent[3] and math.min(minextent[3], c_LS[3]) or c_LS[3]

		maxextent[1] = maxextent[1] and math.max(maxextent[1], c_LS[1]) or c_LS[1]
		maxextent[2] = maxextent[2] and math.max(maxextent[2], c_LS[2]) or c_LS[2]
		maxextent[3] = maxextent[3] and math.max(maxextent[3], c_LS[3]) or c_LS[3]
	end

	print("light space corner points")
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

	local newvp = mu.view_proj({eyepos=center, viewdir=lightdir, up=mc.YAXIS}, frustum_desc)
	local new_light_frustum_points = math3d.frustum_points(newvp)
	add_shadow_debug_policy(
	computil.create_frustum_entity(new_light_frustum_points, "lua calc view frustum",  0xff0000ff))

	---------------------------------------------------------------------------------------------------------

	local shadowcamera = world[csm1.camera_eid].camera
	print("shadow camera view direction:", math3d.tostring(shadowcamera.viewdir))
	print("shadow camera position:", math3d.string(shadowcamera.eyepos))

	local shadowcamera_frustum_desc = shadowcamera.frustum
	print(string.format("shadow camera frustum:[l=%f, r=%f, b=%f, t=%f, n=%f, f=%f]", 
		shadowcamera_frustum_desc.l, shadowcamera_frustum_desc.r, 
		shadowcamera_frustum_desc.b, shadowcamera_frustum_desc.t, 
		shadowcamera_frustum_desc.n, shadowcamera_frustum_desc.f))

	local shadow_viewproj = mu.view_proj(shadowcamera)
	local shadowcamera_frustum_points = math3d.frustum_points(shadow_viewproj)

	print("shadow view frustm point")
	print_frustum_points(shadowcamera_frustum_points)
	add_shadow_debug_policy(
	computil.create_frustum_entity(shadowcamera_frustum_points, "view frustum", 0xffffff00))

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

	local shadow_matrix = math3d.mul(shadowutil.shadow_crop_matrix(), shadow_viewproj)
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
	if linear_shadow then

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

function dbg_sm_sys:data_changed()
	for _, eid in record_camera_state_mb:unpack() do
		log_split_distance()
		create_debug_entity(eid)

		--check_shadow_matrix()
	end
end
