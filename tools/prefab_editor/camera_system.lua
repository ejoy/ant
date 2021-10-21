local ecs = ...
local world = ecs.world
local w = world.w

local iom		= ecs.import.interface "ant.objcontroller|obj_motion"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local camera_mgr= ecs.require "camera_manager"
local math3d	= require "math3d"
local utils		= ecs.require "mathutils"
local inspector = ecs.require "widget.inspector"

local camera_sys	= ecs.system "camera_system"
local global_data 	= require "common.global_data"
local event_camera_control = world:sub {"camera"}
local camera_init_eye_pos <const> = {5, 5, 5, 1}
local camera_init_target <const> = {0, 0,  0, 1}
local camera_target = math3d.ref(math3d.vector(0, 0, 0, 1))
local camera_distance
local zoom_speed <const> = 1
local wheel_speed <const> = 0.5
local pan_speed <const> = 0.5
local rotation_speed <const> = 1

local function view_to_world(view_pos)
	--local camerasrt = iom.srt(irq.main_camera())
	--local camer_worldmat = iom.worldmat(irq.main_camera())

	--FIX ME: iom.worldmat() could not be used in some stage
	local srtmat = math3d.matrix(irq.main_camera().camera.srt)

	return math3d.transform(srtmat, view_pos, 0)
end

local function camera_update_eye_pos(camera)
	local camera_ref = irq.main_camera()
	iom.set_position(camera_ref, math3d.sub(camera_target, math3d.mul(iom.get_direction(camera_ref), camera_distance)))
end

local function camera_rotate(dx, dy)
	iom.rotate(irq.main_camera(), dy * rotation_speed, dx * rotation_speed)
	camera_update_eye_pos()
	world:pub {"Camera", "rotate"}
end

local function camera_pan(dx, dy)
	local world_dir = view_to_world({dy * pan_speed, dx * pan_speed, 0})
	local viewdir = iom.get_direction(irq.main_camera())
	camera_target.v = math3d.add(camera_target, math3d.cross(viewdir, world_dir))
	camera_update_eye_pos()
	world:pub {"Camera", "pan"}
end

local function camera_zoom(dx)
	camera_distance = camera_distance + dx * wheel_speed
	camera_update_eye_pos()
	world:pub {"Camera", "zoom"}
end

local function camera_reset(eyepos, target)
	camera_target.v = target
	camera_distance = math3d.length(math3d.sub(camera_target, eyepos))
	iom.set_view(irq.main_camera(), eyepos, math3d.normalize(math3d.sub(camera_target, eyepos)), {0, 1, 0})
end

local mb_camera_changed = world:sub{"camera_changed", "main_queue"}

function camera_sys:entity_ready()
	for _ in mb_camera_changed:each() do
		camera_reset(camera_init_eye_pos, camera_init_target)
	end
end

local PAN_LEFT = false
local PAN_RIGHT = false
local ZOOM_FORWARD = false
local ZOOM_BACK = false
local icamera = ecs.import.interface "ant.camera|camera"
local function update_second_view_camera()
    if not camera_mgr.second_camera then return end
    -- local rc = world[camera_mgr.second_camera]._rendercache
	-- rc.viewmat = icamera.calc_viewmat(camera_mgr.second_camera)
    -- rc.projmat = icamera.calc_projmat(camera_mgr.second_camera)--math3d.projmat(world[camera_mgr.second_camera]._rendercache.frustum)--
	-- rc.viewprojmat = icamera.calc_viewproj(camera_mgr.second_camera)
end

local keypress_mb = world:sub{"keyboard"}
local event_camera_edit = world:sub{"CameraEdit"}
local mouse_drag = world:sub {"mousedrag"}
local mouse_move = world:sub {"mousemove"}
local mouse_down = world:sub {"mousedown"}
local mouse_up = world:sub {"mouseup"}
local select_area
local last_mouse_pos
local hit_plane
local dist_to_plane
local current_dir = math3d.ref()
local centre_pos = math3d.ref()
local function selectBoundary(hp)
	if not hp[1] or not hp[2] then return end
	last_mouse_pos = hp
	local boundary = camera_mgr.get_editor_data(camera_mgr.second_camera).far_boundary
	if not boundary then return end
	for i, v in ipairs(boundary) do
		local sp1 = utils.world_to_screen(camera_mgr.main_camera, v[1])
		local sp2 = utils.world_to_screen(camera_mgr.main_camera, v[2])
		local dist = utils.point_to_line_distance2D(sp1, sp2, {hp[1] - global_data.viewport.x, hp[2] - global_data.viewport.y})
		if dist < 5.0 then
			return i
		end
	end
end

local ctrl_state = false

function camera_sys:handle_camera_event()
	for _, what, eid, value in event_camera_edit:unpack() do
		if what == "target" then
			camera_mgr.set_target(eid, value)
			inspector.update_ui()
		elseif what == "dist" then
			camera_mgr.set_dist_to_target(eid, value)
		elseif what == "fov" then
			icamera.set_frustum_fov(eid, value)
		elseif what == "near" then
			icamera.set_frustum_near(eid, value)
		elseif what == "far" then
			icamera.set_frustum_far(eid, value)
		end
	end
	
	update_second_view_camera()

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
		ctrl_state = state.CTRL
	end

	if PAN_LEFT then
		camera_pan(0.2, 0)
	elseif PAN_RIGHT then
		camera_pan(-0.2, 0)
	elseif ZOOM_FORWARD then
		camera_zoom(-0.2)
	elseif ZOOM_BACK then
		camera_zoom(0.2)
	end

	if global_data.mouse_move and camera_mgr.second_camera and not camera_mgr.select_frustum then
		if select_area then
			camera_mgr.highlight_frustum(camera_mgr.second_camera, select_area, false)
		end
		select_area = selectBoundary({global_data.mouse_pos_x, global_data.mouse_pos_y})
		if select_area then
			camera_mgr.highlight_frustum(camera_mgr.second_camera, select_area, true)
		end
	end

	for _, what, x, y in mouse_down:unpack() do
		if what == "LEFT" then
			--local x, y = utils.mouse_pos_in_view(x, y)
			if camera_mgr.second_camera then
				select_area = selectBoundary({x, y})
				if select_area then
					camera_mgr.select_frustum = true
					camera_mgr.highlight_frustum(camera_mgr.second_camera, select_area, true)
					local boundary = camera_mgr.get_editor_data(camera_mgr.second_camera).far_boundary
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

	for _, what, x, y in mouse_up:unpack() do
		if what == "LEFT" and camera_mgr.second_camera then
			if select_area then
				camera_mgr.highlight_frustum(camera_mgr.second_camera, select_area, false)
				select_area = nil
			end
			camera_mgr.select_frustum = false
		end
	end
	
	for _,what,x,y in event_camera_control:unpack() do
		if not camera_mgr.select_frustum then
			if what == "rotate" then
				camera_rotate(x, y)
			elseif what == "pan" and not ctrl_state then
				camera_pan(x, y)
			elseif what == "zoom" then
				camera_zoom(x)
			elseif what == "reset" then
				camera_reset(camera_init_eye_pos, camera_init_target)
			end
		end
	end

	for _, what, x, y, dx, dy in mouse_drag:unpack() do
		if what == "LEFT" then
			if select_area and hit_plane then
				local curpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, {x, y}), hit_plane)
				local proj_len = math3d.dot(current_dir, math3d.sub(curpos, centre_pos))
				local aspect = 1.0
				if select_area == camera_mgr.FRUSTUM_LEFT or select_area == camera_mgr.FRUSTUM_RIGHT then
					aspect = icamera.get_frustum(camera_mgr.second_camera).aspect
				end
				local half_fov = math.atan(proj_len / dist_to_plane / aspect )
				camera_mgr.set_frustum_fov(camera_mgr.second_camera, 2 * math.deg(half_fov))
				inspector.update_ui(true)
			end
		elseif what == "MIDDLE" then
			camera_pan(dx, dy)
		elseif what == "RIGHT" then
			camera_rotate(dx, dy)
		end
	end

end

function camera_sys:update_camera()
	if not camera_mgr.second_camera then
		return
	end

	w:sync("camera:in", camera_mgr.second_camera)
	local camera = camera_mgr.second_camera.camera
	if camera then
		local worldmat = camera.worldmat
		local pos, dir = math3d.index(worldmat, 4, 3)
		camera.viewmat = math3d.lookto(pos, dir, camera.updir)
		camera.projmat = math3d.projmat(camera.frustum)
		camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
	end
end
