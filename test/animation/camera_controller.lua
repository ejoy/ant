local ecs = ...
local world = ecs.world

local math3d  = require "math3d"

local m = ecs.system "camera_controller"
m.require_interface "ant.render|camera"
m.require_interface "ant.camera_controller|camera_motion"

local eventCameraControl = world:sub {"camera"}
local cameraInitEyepos <const> = {1.6, 1.8,-1.8, 1}
local cameraInitTarget <const> = {0, 0.9, 0, 1}
local cameraTarget
local cameraDistance
local cameraId

local function cameraUpdateEyepos(camera)
	camera.eyepos.v = math3d.sub(cameraTarget, math3d.mul(camera.viewdir, cameraDistance))
end

local function cameraRotate(dx, dy)
	local camera_motion = world:interface "ant.camera_controller|camera_motion"
	camera_motion.rotate_around_point(cameraId, cameraTarget, cameraDistance, dy, dx, 0.6)
end

local function cameraPan(dx, dy)
	local camera = world[cameraId].camera
	cameraTarget.v = math3d.add(cameraTarget, math3d.cross(camera.viewdir, {dy,dx,0,1}))
	cameraUpdateEyepos(camera)
end

local function cameraZoom(dx)
	local camera = world[cameraId].camera
	cameraDistance = cameraDistance + dx
	cameraUpdateEyepos(camera)
end

local function cameraReset(eyepos, target)
	local camera = world[cameraId].camera
	cameraTarget.v = target
	cameraDistance = math3d.length(math3d.sub(cameraTarget, eyepos))
	camera.eyepos.v = eyepos
	camera.viewdir = math3d.normalize(math3d.sub(cameraTarget, eyepos))
end

local function cameraInit()
	cameraTarget = math3d.ref "vector"
	local camera = world:interface "ant.render|camera"
	cameraId = camera.create {
		eyepos = {0,0,0,1},
		viewdir = {0,1,0,0},
	}
	camera.bind(cameraId, "main_queue")
end

function m:post_init()
	cameraInit()
	cameraReset(cameraInitEyepos, cameraInitTarget)
end

function m:camera_control()
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
