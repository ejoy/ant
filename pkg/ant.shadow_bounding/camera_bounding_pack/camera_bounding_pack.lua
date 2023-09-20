local ecs   = ...
local world = ecs.world
local w     = world.w
local cbp_sys = ecs.system "camera_bounding_pack_system"
local math3d    = require "math3d"

function cbp_sys:update_camera()
    local sbe = w:first "shadow_bounding:update"
    local mq = w:first "main_queue camera_ref:in"
	local ce <close> = world:entity(mq.camera_ref, "camera_changed?in camera:in scene:in")
    if sbe and ce and ce.camera_changed then
		local world_frustum_points = math3d.frustum_points(ce.camera.viewprojmat)
		local camera_min, camera_max = math3d.minmax(world_frustum_points)
		math3d.unmark(sbe.shadow_bounding.camera_aabb)
		sbe.shadow_bounding.camera_aabb = math3d.marked_aabb(camera_min, camera_max)
        w:submit(sbe)  
    end
end