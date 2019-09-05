local util = {}; util.__index = util

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local cu 		= require "components.util"
local mathbaselib 	= require "math3d.baselib"

function util.focus_point(world, pt)
	local mq = world:first_entity "main_queue"
	local camera = util.get_camera(world, mq.camera_tag)
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

		local mq = world:first_entity "main_queue"
		local camera = util.get_camera(world, mq.camera_tag)
		local center = ms({sphere[1], sphere[2], sphere[3], 1.0}, "P")
		ms(camera.viewdir, center, camera.eyepos, "-n=")
	
		ms(camera.eyepos, center, "=")
		move_camera_along_viewdir(camera, sphere[4] * 2)
		calc_camera_distance(camera, bounding, 1)
	
		--print(ms(camera.eyepos, "V"))
		return true		
	end
end

function util.create_camera_mgr_entity(world, main_camera)
	return world:create_entity {
		name = "camera_manager",
		camera_mgr = {
			cameras = {
				main_view = main_camera,
			}
		}
	}
end

function util.bind_camera(world, name, camera)
	local entity = assert(world:first_entity "camera_mgr")
	local cameras = entity.camera_mgr.cameras
	if cameras[name] then
		log.error("already bind camera:", name)
	end

	local comp = world:create_component("camera", camera)
	cameras[name] = comp
	return comp
end

function util.unbind_camera(cameramgr_entity, name)
	local mgr = cameramgr_entity.camera_mgr
	mgr.cameras[name] = nil
end

function util.get_camera(world, name)
	local cameramgr_entity = world:first_entity "camera_mgr"
	local mgr = cameramgr_entity.camera_mgr
	return mgr.cameras[name]
end

return util