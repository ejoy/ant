local ecs = ...
local world = ecs.world
local iom = world:interface "ant.objcontroller|obj_motion"
local camera_mgr = require "camera_manager"(world)
local math3d  = require "math3d"
local utils = require "mathutils"(world)
local inspector = require "widget.inspector"(world)
local m = ecs.system "camera_system"

local event_camera_control = world:sub {"camera"}
local camera_init_eye_pos <const> = {5, 5, -5, 1}
local camera_init_target <const> = {0, 0,  0, 1}
local camera_target
local camera_distance
local camera_id
local zoom_speed <const> = 1
local wheel_speed <const> = 0.5
local pan_speed <const> = 0.5
local rotation_speed <const> = 1

local function view_to_world(view_pos)
	local camerasrt = iom.srt(camera_id)
	return math3d.transform(camerasrt, view_pos, 0)
end

local function world_to_screen(world_pos)
	
end

local function camera_update_eye_pos(camera)
	iom.set_position(camera_id, math3d.sub(camera_target, math3d.mul(iom.get_direction(camera_id), camera_distance)))
end

local function camera_rotate(dx, dy)
	iom.rotate(camera_id, dy * rotation_speed, dx * rotation_speed)
	camera_update_eye_pos()
end

local function camera_pan(dx, dy)
	local world_dir = view_to_world({dy * pan_speed, dx * pan_speed, 0})
	local viewdir = iom.get_direction(camera_id)
	camera_target.v = math3d.add(camera_target, math3d.cross(viewdir, world_dir))
	camera_update_eye_pos()
end

local function camera_zoom(dx)
	camera_distance = camera_distance + dx * wheel_speed
	camera_update_eye_pos()
end

local function camera_reset(eyepos, target)
	camera_target.v = target
	camera_distance = math3d.length(math3d.sub(camera_target, eyepos))
	iom.set_view(camera_id, eyepos, math3d.normalize(math3d.sub(camera_target, eyepos)))
end

local function camera_init()
	camera_target = math3d.ref()
	camera_id = world[world:singleton_entity_id "main_queue"].camera_eid
end

function m:post_init()
	camera_init()
	camera_reset(camera_init_eye_pos, camera_init_target)
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

local event_camera_edit = world:sub{"CameraEdit"}
local mouse_drag = world:sub {"mousedrag"}
local mouse_move = world:sub {"mousemove"}
local mouse_down = world:sub {"mousedown"}
local mouse_up = world:sub {"mouseup"}
local select_area = 0
local last_mouse_pos
local hit_plane
local dist_to_plane
local current_dir = math3d.ref()
local centre_pos = math3d.ref()
local function selectBoundary(hp)
	last_mouse_pos = hp
	local boundary = camera_mgr.camera_list[camera_mgr.second_camera].far_boundary
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
	for _, what, x, y in mouse_move:unpack() do
		if what == "UNKNOWN" then
			if camera_mgr.camera_list[camera_mgr.second_camera] then
				local x, y = utils.adjust_mouse_pos(x, y)
				select_area = selectBoundary({x, y})
			end
		end
	end
	
	for _, what, x, y in mouse_down:unpack() do
		if what == "LEFT" then
			local x, y = utils.adjust_mouse_pos(x, y)
			if camera_mgr.camera_list[camera_mgr.second_camera] then
				select_area = selectBoundary({x, y})
				if select_area ~= 0 then
					local boundary = camera_mgr.camera_list[camera_mgr.second_camera].far_boundary
					local lb_point = boundary[1][1]
					local lt_point = boundary[2][1]
					local rt_point = boundary[3][1]
					local rb_point = boundary[4][1]
					centre_pos.v = math3d.vector(0.5 * (lb_point[1] + rt_point[1]), 0.5 * (lb_point[2] + rt_point[2]), 0.5 * (lb_point[3] + rt_point[3]))
					hit_plane = {dir = math3d.totable(iom.get_direction(camera_mgr.second_camera)), pos = math3d.totable(centre_pos)}
					dist_to_plane = math3d.length(math3d.sub(centre_pos, iom.get_position(camera_mgr.second_camera)))
					local mid_pos
					if select_area == camera_mgr.FRUSTUM_LEFT then
						mid_pos = math3d.vector(0.5 * (lb_point[1] + lt_point[1]), 0.5 * (lb_point[2] + lt_point[2]), 0.5 * (lb_point[3] + lt_point[3]))
					elseif select_area == camera_mgr.FRUSTUM_TOP then
						mid_pos = math3d.vector(0.5 * (rt_point[1] + lt_point[1]), 0.5 * (rt_point[2] + lt_point[2]), 0.5 * (rt_point[3] + lt_point[3]))
					elseif select_area == camera_mgr.FRUSTUM_RIGHT then
						mid_pos = math3d.vector(0.5 * (rt_point[1] + rb_point[1]), 0.5 * (rt_point[2] + rb_point[2]), 0.5 * (rt_point[3] + rb_point[3]))
					elseif select_area == camera_mgr.FRUSTUM_BOTTOM then
						mid_pos = math3d.vector(0.5 * (lb_point[1] + rb_point[1]), 0.5 * (lb_point[2] + rb_point[2]), 0.5 * (lb_point[3] + rb_point[3]))
					end
					current_dir.v = math3d.normalize(math3d.sub(mid_pos, centre_pos))
				end
			end
		end
	end

	camera_mgr.select_frustum = (select_area ~= 0)

	for _, what, x, y in mouse_up:unpack() do
		if what == "LEFT" then
		end
	end

	for _, what, x, y, dx, dy in mouse_drag:unpack() do
		if what == "LEFT" and select_area ~= 0 then
			local ax, ay = utils.adjust_mouse_pos(x, y)
			--local downpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, last_mouse_pos), hit_plane)
			local curpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, {ax, ay}), hit_plane)
			local proj_len = math3d.dot(current_dir, math3d.sub(curpos, centre_pos))
			local aspect = 1.0
			if select_area == camera_mgr.FRUSTUM_LEFT or select_area == camera_mgr.FRUSTUM_RIGHT then
				aspect = icamera.get_frustum(camera_mgr.second_camera).aspect
			end
			local half_fov = math.atan(proj_len / dist_to_plane / aspect )
			camera_mgr.set_frustum_fov(camera_mgr.second_camera, 2 * math.deg(half_fov))
			inspector.update_ui(true)
		end
	end

	for _, what, eid, value in event_camera_edit:unpack() do
		if what == "target" then
			camera_mgr.set_target(eid, value)
			inspector.update_ui()
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
	
	update_second_view_camera()

	for _,what,x,y in event_camera_control:unpack() do
		if select_area == 0 then
			if what == "rotate" then
				camera_rotate(x, y)
			elseif what == "pan" then
				camera_pan(x, y)
			elseif what == "zoom" then
				camera_zoom(x)
			elseif what == "reset" then
				camera_reset(camera_init_eye_pos, camera_init_target)
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
		camera_pan(0.05, 0)
	elseif PAN_RIGHT then
		camera_pan(-0.05, 0)
	elseif ZOOM_FORWARD then
		camera_zoom(-0.05)
	elseif ZOOM_BACK then
		camera_zoom(0.05)
	end
end
