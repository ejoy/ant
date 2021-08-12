local ecs = ...
local world = ecs.world
local w = world.w

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local irender   = world:interface "ant.render|irender"
local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

local math3d    = require "math3d"

local ientity   = world:interface "ant.render|entity"
local ilight	= world:interface "ant.render|light"
local ishadow	= world:interface "ant.render|ishadow"
local icamera	= world:interface "ant.camera|camera"
local iom		= world:interface "ant.objcontroller|obj_motion"

local shadowdbg_sys = ecs.system "shadow_debug_system"

local quadsize = 192
local quadmaterial = "/pkg/ant.resources/materials/shadow/shadowmap_quad.material"

local frustum_colors = {
	0xff0000ff, 0xff00ff00, 0xffff0000, 0xffffff00,
}

local function find_csm_entity(index)
	for se in w:select "csm_queue csm:in" do
		if se.csm.index == index then
			return se.csm
		end
	end
end

local debug_entities = {}
local function create_debug_entity()
	for _, eid in ipairs(debug_entities) do
		world:remove_entity(eid)
	end
	debug_entities = {}

	do
		local splitnum = ishadow.split_num()
		local rect = {x=0, y=0, w=quadsize*splitnum, h=quadsize}
		debug_entities[#debug_entities+1] = ientity.create_quad_entity(rect, quadmaterial, "csm_quad")
	end

	do
		for e in w:select "main_queue camera_ref:in" do
			local camera = icamera.find_camera(e.camera_ref)
			for idx, f in ipairs(ishadow.split_frustums()) do
				local vp = math3d.mul(math3d.projmat(f), camera.viewmat)
				debug_entities[#debug_entities+1] = ientity.create_frustum_entity(
					math3d.frustum_points(vp), "frusutm:main_view", frustum_colors[idx]
				)
			end
		end
	end
	
	for se in w:select "csm_queue csm:in camera_ref:in name:in" do
		local idx = se.csm.index
		local ce = icamera.find_camera(se.camera_ref)
		local rc = ce._rendercache
		local frustum_points = math3d.frustum_points(rc.viewprojmat)
		local color = frustum_colors[idx]

		debug_entities[#debug_entities+1] = ientity.create_frustum_entity(frustum_points, "frusutm:" .. se.name, color)
		debug_entities[#debug_entities+1] = ientity.create_axis_entity(math3d.tovalue(rc.worldmat), "csm_axis:" .. idx, color)
	end
end

local function print_points(points)
	for idx, p in ipairs(points) do
		print(string.format("\tpoint[%d]:[%s]", idx, math3d.tostring(p)))
	end
end

local blit_shadowmap_viewid = viewidmgr.generate "blit_shadowmap"

local function check_shadow_matrix()
	local se = world[find_csm_entity(1)]
	local function directional_light()
		for _, eid in world:each "light_type" do
			local e = world[eid]
			if e.light_type == "directional" then
				return eid
			end
		end
	end
	local lightdir = iom.get_direction(directional_light())
	print("light direction:", math3d.tostring(lightdir))

	for e in w:select "main_queue camera_ref:in" do
		print("eye posision:", math3d.tostring(iom.get_position(e.camera_ref)))
		print("view direction:", math3d.tostring(iom.get_direction(e.camera_ref)))

		local camera_2_origin = math3d.length(iom.get_position(e.camera_ref))
		print("check eye position to [0, 0, 0] distance:", camera_2_origin)

		local f = ishadow.calc_split_frustums(icamera.get_frustum(e.camera_ref))[1]
		local dis_n, dis_f = f.n, f.f
		print("csm1 distance:", dis_n, dis_f)

		if dis_n <= camera_2_origin and camera_2_origin <= dis_f then
			print("origin is on csm1")
		else
			print("origin is not on csm1")
		end
	

		local csm_index = se.csm.index
		local ff = ishadow.calc_split_frustums(icamera.get_frustum(e.camera_ref))
		local split_frustum_desc = ff[csm_index]
		local viewmat = icamera.calc_viewmat(e.camera_ref)
		local vp = math3d.mul(math3d.projmat(split_frustum_desc), viewmat)

		local frustum_points = math3d.frustum_points(vp)
		local center = math3d.points_center(frustum_points)

		print("view split frusutm corners, center: " .. math3d.tostring(center))
		print_points(frustum_points)

		local lightmatrix = math3d.lookto(center, lightdir)
		local corners_LS = {}
		for _, c in ipairs(frustum_points) do
			corners_LS[#corners_LS+1] = math3d.transform(lightmatrix, c, 1)
		end

		local minextent, maxextent = math3d.minmax(corners_LS)
		minextent, maxextent = math3d.tovalue(minextent), math3d.tovalue(maxextent)
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
		ientity.create_frustum_entity(new_light_frustum_points, "lua calc view frustum",  0xff0000ff)
		
		---------------------------------------------------------------------------------------------------------
		local shadow_camera_ref = se.camera_ref
		print("shadow camera view direction:", math3d.tostring(iom.get_direction(shadow_camera_ref)))
		print("shadow camera position:", math3d.tostring(iom.get_position(shadow_camera_ref)))

		local shadowcamera_frustum_desc = icamera.get_frustum(shadow_camera_ref)
		print(string.format("shadow camera frustum:[l=%f, r=%f, b=%f, t=%f, n=%f, f=%f]", 
			shadowcamera_frustum_desc.l, shadowcamera_frustum_desc.r, 
			shadowcamera_frustum_desc.b, shadowcamera_frustum_desc.t, 
			shadowcamera_frustum_desc.n, shadowcamera_frustum_desc.f))

		local shadow_viewproj = icamera.calc_viewproj(shadow_camera_ref)
		local shadowcamera_frustum_points = math3d.frustum_points(shadow_viewproj)

		print("shadow view frustm point")
		print_points(shadowcamera_frustum_points)
		ientity.create_frustum_entity(shadowcamera_frustum_points, "view frustum", 0xffffff00)

		-------------------------------------------------------------------------------------------------
		-- test shadow matrix
		local pt = {-0.00009, -0.01307, 0.1544} --mc.T_ZERO_PT
		local worldmat = {
			0.0, 0.0, -20.02002, -20,
		}

		local origin_CS = math3d.index(shadow_viewproj, 1)
		print(string.format("origin clip space:%s", math3d.tostring(origin_CS)))
		local origin_NDC = math3d.mul(origin_CS, 1 / math3d.index(origin_CS, 1))
		print(string.format("origin ndc space:%s", math3d.tostring(origin_NDC)))

		local cp_mat = ishadow.crop_matrix(csm_index)
		local shadow_matrix = math3d.mul(cp_mat, shadow_viewproj)

		local origin_CS_With_Crop = math3d.transform(shadow_matrix, {0, 0, 0.55, 1}, 1)
		print(string.format("origin clip space with corp:%s", math3d.tostring(origin_CS_With_Crop)))
		local origin_NDC_With_Crop = math3d.mul(origin_CS_With_Crop, 1 / math3d.index(origin_CS_With_Crop, 1))
		print(string.format("origin ndc space with crop:%s", math3d.tostring(origin_NDC_With_Crop)))
		------------------------------------------------------------------------------------------------------------------------
		-- read the shadow map back
		if ishadow.depth_type() == "linear" then
			local size = ishadow.shadowmap_size()
			local fb = fbmgr.get(se.render_target.fb_idx)
			local memory_handle, width, height, pitch = irender.read_render_buffer_content({w=size,h=size}, "RGBA8", fb[1], true)

			local depth = pt[3]
			local x, y = pt[1], pt[2]
			local fx, fy = math.floor(x * width), math.floor(y * height)
			local cx, cy = math.ceil(x * width), math.ceil(y * height)

			local depth0 = memory_handle[fy*pitch+fx]
			local depth1 = memory_handle[fy*pitch+cx]

			local depth2 = memory_handle[cy*pitch+fx]
			local depth3 = memory_handle[cy*pitch+cx]

			print("depth:", depth)
			print("depth0:", depth0, "depth1:", depth1, "depth2:", depth2, "depth3:", depth3)
		end
	end
end

local function log_split_distance()
	for e in w:select "main_queue camera_ref:in" do
		local c = icamera.find_camera(e.camera_ref)
		for idx, f in ipairs(ishadow.calc_split_frustums(icamera.get_frustum(e.camera_ref))) do
			print(string.format("csm%d, distance[%f, %f]", idx, f.n, f.f))
		end
	end

end

local keypress_mb = world:sub{"keyboard"}
function shadowdbg_sys:camera_usage()
	for _, key, press, state in keypress_mb:unpack() do
		if key == "SPACE" and press == 0 then
			log_split_distance()
			create_debug_entity()
		elseif key == "L" and press == 0 then
			local eids = {}
			for se in w:select "csm_queue camera_ref:in csm:in" do
				eids[se.csm.index] = se.camera_ref
			end
			world:pub{"splitview", "change_camera", eids}
		end
	end
end
