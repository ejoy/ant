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

local iom = world:interface "ant.objcontroller|obj_motion"

local function cameraUpdateEyepos()
	local viewdir = iom.get_direction(cameraId)
	iom.set_position(cameraId, math3d.sub(cameraTarget, math3d.mul(viewdir, cameraDistance)))
end

local function cameraRotate(dx, dy)
	iom.rotate_around_point(cameraId, cameraTarget, cameraDistance, dy, dx)
end

local function cameraPan(dx, dy)
	local viewdir = iom.get_direction(cameraId)
	cameraTarget.v = math3d.add(cameraTarget, math3d.cross(viewdir, {dy,dx,0,1}))
	cameraUpdateEyepos()
end

local function cameraZoom(dx)
	cameraDistance = cameraDistance + dx
	cameraUpdateEyepos()
end

local function cameraReset(eyepos, target)
	cameraTarget.v = target
	cameraDistance = math3d.length(math3d.sub(cameraTarget, eyepos))
	iom.set_view(cameraId, eyepos, math3d.normalize(math3d.sub(cameraTarget, eyepos)))
end

local function cameraInit()
	cameraTarget = math3d.ref()
	local camera = world:interface "ant.camera|camera"
	cameraId = camera.create {
		eyepos = {0,0,0,1},
		viewdir = {0,0,1,0},
	}
	camera.bind(cameraId, "main_queue")
end

function m:post_init()
	cameraInit()
	cameraReset(cameraInitEyepos, cameraInitTarget)
end

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
end
