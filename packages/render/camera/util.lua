local util = {}; util.__index = util

function util.queue_camera(world, queuetag)
	local q = world:singleton_entity(queuetag)
	return world[q.camera_eid].camera
end

function util.main_queue_camera(world)
	return util.queue_camera(world, "main_queue")
end

return util