local ecs = ...
local world = ecs.world
local w = world.w

local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local math3d	= require "math3d"
local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local event_camera_control = world:sub {"camera"}
local camera_init_eye_pos <const> = math3d.ref(math3d.vector(5, 5, 5, 1))
local camera_init_target <const> = math3d.ref(mc.ZERO_PT)
local camera_target				= math3d.ref(mc.ZERO_PT)
local camera_distance
local wheel_speed <const>		= 0.5
local pan_speed <const>			= 0.5
local rotation_speed <const>	= 1

local function view_to_world(view_pos)
	local camera_ref = irq.main_camera()
	w:sync("camera:in scene:in", camera_ref)
    local worldmat = camera_ref.scene._worldmat
	return math3d.transform(worldmat, view_pos, 0)
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
	local world_dir = view_to_world({dy * pan_speed, dx * pan_speed, 0.0})
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

local mb_camera_changed = world:sub{"main_queue", "camera_changed"}

local camera_sys	= ecs.system "camera_system"
function camera_sys:init_world()
	camera_reset(camera_init_eye_pos, camera_init_target)
end

function camera_sys:entity_ready()
	for _ in mb_camera_changed:each() do
		camera_reset(camera_init_eye_pos, camera_init_target)
	end
end

local keypress_mb		= world:sub {"keyboard"}
local mouse_drag		= world:sub {"mousedrag"}

local PAN, ZOOM
function camera_sys:data_changed()
	for _,what,x,y in event_camera_control:unpack() do
		if what == "rotate" then
			camera_rotate(x, y)
		elseif what == "zoom" then
			camera_zoom(x)
		elseif what == "reset" then
			camera_reset(camera_init_eye_pos, camera_init_target)
		end
	end

	for _, key, press, state in keypress_mb:unpack() do
		if not state.CTRL and not state.SHIFT then
			if key == "W" then
				ZOOM = press == 1 and 0.2 or nil
			elseif key == "S" then
				ZOOM = press == 1 and -0.2 or nil
			elseif key == "A" then
				PAN = press == 1 and 0.2 or nil
			elseif key == "D" then
				PAN = press == 1 and -0.2 or nil
			end
		end
	end

	if ZOOM then
		camera_zoom(ZOOM)
	end

	if PAN then
		camera_pan(PAN, 0)
	end

	for _, what, x, y, dx, dy in mouse_drag:unpack() do
		if what == "RIGHT" then
			camera_rotate(dx, dy)
		elseif what == "MIDDLE" then
			--camera_pan(dx, dy)
		end
	end
end
