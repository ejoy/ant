local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local rhwi    = import_package "ant.render".hwi
local math3d  = require "math3d"
local ms, mu  = mathpkg.stack, mathpkg.util

local m = ecs.system "camera_controller"
m.require_interface "ant.render|camera"

local eventCameraControl = world:sub {"camera"}
local kMinThreshold <const> = 0.6
local kMaxThreshold <const> = math.pi - kMinThreshold
local cameraInitEyepos <const> = {1.6, 1.8,-1.8, 1}
local cameraInitTarget <const> = {0, 0.9, 0, 1}
local cameraTarget
local cameraDistance
local cameraId

local function getAngle(v1,v2)
	return math.acos(ms(v1, "n", v2, "n.T")[1])
end

local function cameraRotateX(camera, dx)
	ms(camera.viewdir, ms:euler2quat{0, dx, 0}, "2*n=")
end

local function cameraRotateY(camera, dy)
	local right = ms({0,1,0,1}, camera.viewdir, "xnP")
	ms(camera.viewdir, {type="q", axis=right, radian={dy}}, "2*n=")
end

local function cameraRotate(dx, dy)
	local camera = world[cameraId].camera
	local angle = getAngle(mu.AXIS('Y'), camera.viewdir)
	if  (angle > kMinThreshold or dy > 0) and (angle < kMaxThreshold or dy < 0) then
		cameraRotateY(camera, dy)
	end
	cameraRotateX(camera, dx)
	ms(camera.eyepos, cameraTarget, camera.viewdir, cameraDistance, '*-=')
end

local function cameraReset(eyepos, target)
	local camera = world[cameraId].camera
	ms(cameraTarget, target, "=")
	cameraDistance = {math.sqrt(ms(cameraTarget, eyepos, "-1.T")[1])}
	ms(camera.eyepos, eyepos, "=")
	ms(camera.viewdir, cameraTarget, eyepos, "-n=")
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
		elseif what == "reset" then
			cameraReset(cameraInitEyepos, cameraInitTarget)
		end
	end
end

local eventMouseLeft = world:sub {"mouse", "LEFT"}
local kRotationSpeed <const> = 1
local lastX, lastY

function m:data_changed()
	for _,_,state,x,y in eventMouseLeft:unpack() do
		if state == "MOVE" then
			local dpiX, dpiY = rhwi.dpi()
			world:pub {
				"camera","rotate",
				(x - lastX) / dpiX * kRotationSpeed,
				(y - lastY) / dpiY * kRotationSpeed
			}
			lastX, lastY = x, y
		elseif state == "DOWN" then
			lastX, lastY = x, y
		end
	end
end
