local ecs = ...
local world = ecs.world
local iom = world:interface "ant.objcontroller|obj_motion"
local camera_mgr = require "camera_manager"(world)
local math3d  = require "math3d"
local utils = require "mathutils"(world)
local inspector = require "ui.inspector"(world)
local m = ecs.system "camera_system"

local eventCameraControl = world:sub {"camera"}
local cameraInitEyepos <const> = {2, 2, -2, 1}
local cameraInitTarget <const> = {0, 1,  0, 1}
local cameraTarget
local cameraDistance
local cameraId
local kZoomSpeed <const> = 1
local kWheelSpeed <const> = 0.5
local kPanSpeed <const> = 0.5
local kRotationSpeed <const> = 1

local function view_to_world(view_pos)
	local camerasrt = iom.srt(cameraId)
	return math3d.transform(camerasrt, view_pos, 0)
end

local function world_to_screen(world_pos)
	
end

local function cameraUpdateEyepos(camera)
	iom.set_position(cameraId, math3d.sub(cameraTarget, math3d.mul(iom.get_direction(cameraId), cameraDistance)))
end

local function cameraRotate(dx, dy)
	iom.rotate(cameraId, dy * kRotationSpeed, dx * kRotationSpeed)
	cameraUpdateEyepos()
end

local function cameraPan(dx, dy)
	local world_dir = view_to_world({dy * kPanSpeed, dx * kPanSpeed, 0})
	local viewdir = iom.get_direction(cameraId)
	cameraTarget.v = math3d.add(cameraTarget, math3d.cross(viewdir, world_dir))
	cameraUpdateEyepos()
end

local function cameraZoom(dx)
	cameraDistance = cameraDistance + dx * kWheelSpeed
	cameraUpdateEyepos()
end

local function cameraReset(eyepos, target)
	cameraTarget.v = target
	cameraDistance = math3d.length(math3d.sub(cameraTarget, eyepos))
	iom.set_view(cameraId, eyepos, math3d.normalize(math3d.sub(cameraTarget, eyepos)))
end

local function cameraInit()
	cameraTarget = math3d.ref()
	cameraId = world[world:singleton_entity_id "main_queue"].camera_eid
end

function m:post_init()
	cameraInit()
	cameraReset(cameraInitEyepos, cameraInitTarget)
end
local keypress_mb = world:sub{"keyboard"}
local PAN_LEFT = false
local PAN_RIGHT = false
local ZOOM_FORWARD = false
local ZOOM_BACK = false
local icamera = world:interface "ant.camera|camera"
function update_second_view_camera()
    if not camera_mgr.second_camera then return end
    local rc = world[camera_mgr.second_camera]._rendercache
	rc.viewmat = icamera.calc_viewmat(camera_mgr.second_camera)
    rc.projmat = icamera.calc_projmat(camera_mgr.second_camera)--math3d.projmat(world[camera_mgr.second_camera]._rendercache.frustum)--
	rc.viewprojmat = icamera.calc_viewproj(camera_mgr.second_camera)
end

local eventSceondCamera = world:sub{"ActiveSceondCamera"}
local eventCameraEdit = world:sub{"CameraEdit"}
local mouseDrag = world:sub {"mousedrag"}
local mouseMove = world:sub {"mousemove"}
local mouseDown = world:sub {"mousedown"}
local mouseUp = world:sub {"mouseup"}
local selectArea = 0
local lastMousePos
local hitPlane
local distToPlane
local currentDir = math3d.ref()
local centrePos = math3d.ref()
local function selectBoundary(hp)
	lastMousePos = hp
	local boundary = camera_mgr[camera_mgr.second_camera].far_boundary
	for i, v in ipairs(boundary) do
		local sp1 = utils.world_to_screen(camera_mgr.main_camera, v[1])
		local sp2 = utils.world_to_screen(camera_mgr.main_camera, v[2])
		if utils.point_to_line_distance2D(sp1, sp2, hp) < 5.0 then
			camera_mgr.highlight_frustum(camera_mgr.second_camera, i, true)
			return i
		else
			camera_mgr.highlight_frustum(camera_mgr.second_camera, i, false)
		end
	end
	return 0
end

function m:data_changed()
	camera_mgr.select_frustum = false
	for _, what, x, y in mouseMove:unpack() do
		if what == "UNKNOWN" then
			if camera_mgr[camera_mgr.second_camera] then
				local x, y = utils.adjust_mouse_pos(x, y)
				selectArea = selectBoundary({x, y})
			end
		end
	end
	
	for _, what, x, y in mouseDown:unpack() do
		if what == "LEFT" then
			local x, y = utils.adjust_mouse_pos(x, y)
			if camera_mgr[camera_mgr.second_camera] then
				selectArea = selectBoundary({x, y})
				if selectArea ~= 0 then
					local boundary = camera_mgr[camera_mgr.second_camera].far_boundary
					local lb_point = boundary[1][1]
					local lt_point = boundary[2][1]
					local rt_point = boundary[3][1]
					local rb_point = boundary[4][1]
					centrePos.v = math3d.vector(0.5 * (lb_point[1] + rt_point[1]), 0.5 * (lb_point[2] + rt_point[2]), 0.5 * (lb_point[3] + rt_point[3]))
					hitPlane = {dir = math3d.totable(iom.get_direction(camera_mgr.second_camera)), pos = math3d.totable(centrePos)}
					distToPlane = math3d.length(math3d.sub(centrePos, iom.get_position(camera_mgr.second_camera)))
					local mid_pos
					if selectArea == camera_mgr.FRUSTUM_LEFT then
						mid_pos = math3d.vector(0.5 * (lb_point[1] + lt_point[1]), 0.5 * (lb_point[2] + lt_point[2]), 0.5 * (lb_point[3] + lt_point[3]))
					elseif selectArea == camera_mgr.FRUSTUM_TOP then
						mid_pos = math3d.vector(0.5 * (rt_point[1] + lt_point[1]), 0.5 * (rt_point[2] + lt_point[2]), 0.5 * (rt_point[3] + lt_point[3]))
					elseif selectArea == camera_mgr.FRUSTUM_RIGHT then
						mid_pos = math3d.vector(0.5 * (rt_point[1] + rb_point[1]), 0.5 * (rt_point[2] + rb_point[2]), 0.5 * (rt_point[3] + rb_point[3]))
					elseif selectArea == camera_mgr.FRUSTUM_BOTTOM then
						mid_pos = math3d.vector(0.5 * (lb_point[1] + rb_point[1]), 0.5 * (lb_point[2] + rb_point[2]), 0.5 * (lb_point[3] + rb_point[3]))
					end
					currentDir.v = math3d.normalize(math3d.sub(mid_pos, centrePos))
				end
			end
		end
	end

	camera_mgr.select_frustum = (selectArea ~= 0)

	for _, what, x, y in mouseUp:unpack() do
		if what == "LEFT" then
		end
	end

	for _, what, x, y, dx, dy in mouseDrag:unpack() do
		if what == "LEFT" and selectArea ~= 0 then
			local ax, ay = utils.adjust_mouse_pos(x, y)
			--local downpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, lastMousePos), hitPlane)
			local curpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, {ax, ay}), hitPlane)
			local proj_len = math3d.dot(currentDir, math3d.sub(curpos, centrePos))
			local aspect = 1.0
			if selectArea == camera_mgr.FRUSTUM_LEFT or selectArea == camera_mgr.FRUSTUM_RIGHT then
				aspect = icamera.get_frustum(camera_mgr.second_camera).aspect
			end
			local half_fov = math.atan(proj_len / distToPlane / aspect )
			camera_mgr.set_frustum_fov(camera_mgr.second_camera, 2 * math.deg(half_fov))
			inspector.update_ui()
		end
	end

	for _, what, eid, value in eventCameraEdit:unpack() do
		if what == "target" then
			camera_mgr.set_target(eid, value)
		elseif what == "dist" then
			camera_mgr.set_dist_to_target(eid, value)
		elseif what == "fov" then
			icamera.set_frustum(eid, {
				fov = value
			})
		elseif what == "near" then
			icamera.set_frustum(eid, {
				n = value,
			})
		elseif what == "far" then
			icamera.set_frustum(eid, {
				f = value
			})
		end
	end

	for _, eid in eventSceondCamera:unpack() do
		camera_mgr.set_second_camera(eid)
	end
	
	update_second_view_camera()

	for _,what,x,y in eventCameraControl:unpack() do
		if selectArea == 0 then
			if what == "rotate" then
				cameraRotate(x, y)
			elseif what == "pan" then
				cameraPan(x, y)
			elseif what == "zoom" then
				cameraZoom(x)
			elseif what == "reset" then
				cameraReset(cameraInitEyepos, cameraInitTarget)
			end
		end
	end
	
	for _, key, press, state in keypress_mb:unpack() do
		if not state.CTRL and not state.SHIFT then
			if key == "W" then
				if press == 1 then
					ZOOM_FORWARD = true
				elseif press == 0 then
					ZOOM_FORWARD = false
				end
			elseif key == "S" then
				if press == 1 then
					ZOOM_BACK = true
				elseif press == 0 then
					ZOOM_BACK = false
				end
			elseif key == "A" then
				if press == 1 then
					PAN_LEFT = true
				elseif press == 0 then
					PAN_LEFT = false
				end
			elseif key == "D" then
				if press == 1 then
					PAN_RIGHT = true
				elseif press == 0 then
					PAN_RIGHT = false
				end
			end
		end
	end

	if PAN_LEFT then
		cameraPan(0.05, 0)
	elseif PAN_RIGHT then
		cameraPan(-0.05, 0)
	elseif ZOOM_FORWARD then
		cameraZoom(-0.05)
	elseif ZOOM_BACK then
		cameraZoom(0.05)
	end
end
