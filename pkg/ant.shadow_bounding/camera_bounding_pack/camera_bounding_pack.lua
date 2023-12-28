local ecs   = ...
local world = ecs.world
local w     = world.w
local cbp_sys = ecs.system "camera_bounding_pack_system"
local icamera = ecs.require "ant.camera|camera"

local math3d    = require "math3d"

function cbp_sys:update_camera()
    local C = icamera.main_camera_changed()
    if C then
        w:extend(C, "camera:in")
        local sbe = w:first "shadow_bounding:update"
        math3d.unmark(sbe.shadow_bounding.camera_aabb)
        sbe.shadow_bounding.camera_aabb = math3d.marked_aabb(math3d.minmax(math3d.frustum_points(C.camera.viewprojmat)))
        w:submit(sbe)
    end
end