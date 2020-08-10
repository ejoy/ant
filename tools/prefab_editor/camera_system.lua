local ecs = ...
local world = ecs.world

local math3d  = require "math3d"

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
local iom = world:interface "ant.objcontroller|obj_motion"
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
	-- local camera = world:interface "ant.camera|camera"
	-- cameraId = camera.create {
	-- 	eyepos = {0,0,0,1},
	-- 	viewdir = {0,0,1,0},
	-- }
	-- camera.bind(cameraId, "main_queue")

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
function m:data_changed()
	for _,what,x,y in eventCameraControl:unpack() do
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
