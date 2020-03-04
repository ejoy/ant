local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local rhwi    = import_package "ant.render".hwi
local math3d  = require "math3d"
local ms, mu  = mathpkg.stack, mathpkg.util

local m = ecs.system "camera_controller"
m.require_interface "ant.render|camera"

local eventMouseLeft = world:sub {"mouse", "LEFT"}
local kRotationSpeed <const> = 1
local kMinThreshold <const> = 0.6
local kMaxThreshold <const> = math.pi - kMinThreshold
local cameraTarget
local cameraDistance
local cameraId
local lastX, lastY

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

local function cameraInit(eyepos, target)
	cameraTarget = math3d.ref "vector"
	ms(cameraTarget, target, "=")
	local viewdir = ms(cameraTarget, eyepos, "-nT")
	cameraDistance = {math.sqrt(ms(cameraTarget, eyepos, "-1.T")[1])}

	local camera = world:interface "ant.render|camera"
	cameraId = camera.create {
        eyepos = eyepos,
        viewdir = viewdir,
	}
    camera.bind(cameraId, "main_queue")
end

function m:post_init()
	cameraInit({1.6, 1.8,-1.8, 1}, {0, 0.9, 0, 1})
end

function m:camera_control()
	for _,_,state,x,y in eventMouseLeft:unpack() do
		if state == "MOVE" then
			local dpiX, dpiY = rhwi.dpi()
			cameraRotate(
				(x - lastX) / dpiX * kRotationSpeed,
				(y - lastY) / dpiY * kRotationSpeed
			)
			lastX, lastY = x, y
		elseif state == "DOWN" then
			lastX, lastY = x, y
		end
	end
end
