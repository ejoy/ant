local util = {}; util.__index = util

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local cu 		= require "components.util"
local mathbaselib 	= require "math3d.baselib"

function util.focus_point(world, pt)
	local camera = util.main_queue_camera(world)
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
	if bounding then
		local sphere = bounding:get "sphere"
		local camera = util.main_queue_camera(world)
		local center = ms({sphere[1], sphere[2], sphere[3], 1.0}, "P")
		ms(camera.viewdir, center, camera.eyepos, "-n=")
	
		ms(camera.eyepos, center, "=")
		move_camera_along_viewdir(camera, sphere[4] * 2)
		calc_camera_distance(camera, bounding, 1)
	
		--print(ms(camera.eyepos, "V"))
		return true		
	end
end

function util.queue_camera(world, queuetag)
	local q = world:first_entity(queuetag)
	return world[q.camera_eid].camera
end

function util.main_queue_camera(world)
	return util.queue_camera(world, "main_queue")
end

return util