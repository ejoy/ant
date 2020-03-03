local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local rhwi    = import_package "ant.render".hwi
local math3d  = require "math3d"
local ms, mu  = mathpkg.stack, mathpkg.util
local point2d = mathpkg.point2d

local m = ecs.system "camera_controller2"

m.require_interface "ant.render|camera"

local function get_camera()
	local mq = world:singleton_entity "main_queue"
	return world[mq.camera_eid].camera
end

local eventMouseLeft = world:sub {"mouse", "LEFT"}
local dpi_x, dpi_y
local last_xy
local target, distance
local rotation_speed = 0.05

local function getangle(v1,v2)
	local x1,y1,z1 = table.unpack(ms(v1, "T"))
	local x2,y2,z2 = table.unpack(ms(v2, "T"))
	local dot = x1*x2 + y1*y2 + z1*z2 
	local sq1 = x1*x1 + y1*y1 + z1*z1
	local sq2 = x2*x2 + y2*y2 + z2*z2
	return math.acos(dot/math.sqrt(sq1*sq2))
end

local function is_parallel(v1,v2,threshold)
	local angle = getangle(v1,v2)
	return angle < threshold or angle > math.pi-threshold
end

local function rotate_round_point(camera, point, distance, dx, dy)
	local right, up = ms:base_axes(camera.viewdir)
	--if is_parallel(mu.AXIS('Y'), camera.viewdir, 0.5) then
		--ms(camera.viewdir, {type="q", axis=up, radian={dx}}, camera.viewdir, "*n=")
	--else
		--ms(camera.viewdir, {type="q", axis=up, radian={dx}}, {type="q", axis=right, radian={dy}}, "3**n=")
		ms(camera.viewdir, ms:euler2quat{dy/2, 0, 0}, "2*n=")
		print(dy,dx)
	--end
	ms(camera.eyepos, point, camera.viewdir, {distance}, '*-=')
end

local camera = world:interface "ant.render|camera"

local function camera_reset(camera, target)
	ms(target, {0, 0, 0, 1}, "=")
	ms(camera.eyepos, {3, 3, -3, 1}, "=")
	ms(camera.viewdir, target, camera.eyepos, "-n=")
end

function m:post_init()
	dpi_x, dpi_y = rhwi.dpi()
    camera.bind(camera.create {
        eyepos = { 1.6, 1.8,-1.8, 1.0},
        viewdir = {-0.6,-0.4, 0.7, 0.0},
	}, "main_queue")
	target = math3d.ref "vector"
	ms(target, {0, 0, 0, 1}, "=")
	camera_reset(get_camera(), target)
end

local function convertxy(p2d)
	p2d.x = p2d.x / dpi_x
	p2d.y = p2d.y / dpi_y
	return p2d
end

function m:camera_control()
	local camera = get_camera()
	for _,_,state,x,y in eventMouseLeft:unpack() do
		if state == "MOVE" then
			local xy = point2d(x, y)
			if last_xy then
				local delta = convertxy(xy - last_xy) * rotation_speed
				rotate_round_point(camera, target, distance, delta.x, delta.y)
			end
		elseif state == "DOWN" then
			last_xy = point2d(x, y)
			distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
		end
	end
end
