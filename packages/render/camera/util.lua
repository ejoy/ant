local util = {}; util.__index = util

local math = import_package "ant.math"
local ms = math.stack

local mathbaselib = require "math3d.baselib"

local cu = require "components.util"

local function deep_copy(t)
	if type(t) == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

function util.focus_point(world, pt)
	local maincamera = world:first_entity("main_queue")
	local camera = maincamera.camera
	ms(camera.viewdir, pt, camera.eyepos, "-n=")
end

local function move_camera_along_viewdir(camera, delta)
	local pos, dir = camera.eyepos, camera.viewdir
	return ms(pos, pos, dir, {delta}, "*-=")
end

local function calc_camera_distance(camera, bounding, delta)
	local maxcount = 10
	local count = 0
	while true do
		local _, _, vp = ms:view_proj(camera, camera.frustum, true)
		local frustum = mathbaselib.new_frustum(ms, vp)

		count = count + 1
		local result = frustum:intersect(bounding)
		if result == "inside" or count >= maxcount then
			break
		end

		move_camera_along_viewdir(camera, delta * count)
	end
end

function util.focus_obj(world, eid)
	local entity = assert(world[eid])
	local bounding = cu.entity_bounding(entity)
	local sphere = bounding:get "sphere"

	local mq = world:first_entity("main_queue")
	local camera = mq.camera
	local center = ms({sphere[1], sphere[2], sphere[3], 1.0}, "P")
	ms(camera.viewdir, center, camera.eyepos, "-n=")

	ms(camera.eyepos, center, "=")
	move_camera_along_viewdir(camera, sphere[4] * 2)
	calc_camera_distance(camera, bounding, 1)

	--print(ms(camera.eyepos, "V"))
	return true
end

return util