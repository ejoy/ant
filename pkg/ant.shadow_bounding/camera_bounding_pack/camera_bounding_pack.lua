local ecs   = ...
local world = ecs.world
local w     = world.w
local cbp_sys = ecs.system "camera_bounding_pack_system"
local math3d    = require "math3d"

function cbp_sys:update_camera()
    if not w:first "camera_changed" then
        return
    end

    local sbe = w:first "shadow_bounding:update"
    if not sbe then
        return 
    end

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = world:entity(mq.camera_ref, "camera_changed?in camera:in scene:in")
    if ce and ce.camera_changed then
        math3d.unmark(sbe.shadow_bounding.camera_aabb)
        sbe.shadow_bounding.camera_aabb = math3d.marked_aabb(math3d.minmax(math3d.frustum_points(ce.camera.viewprojmat)))
        w:submit(sbe)
    end
end