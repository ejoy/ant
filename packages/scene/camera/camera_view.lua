local ecs = ...
local world = ecs.world
local math3d = require "mat3d"

local cameraview_sys = ecs.system "camera_view_system"

function cameraview_sys:update_camera()
    for _, eid in world:each "camera" do
        local rc = world[eid]._rendercache
        rc.viewmat = math3d.inverse_fast(rc.worldmat)
        rc.projmat = math3d.projmat(rc.frustum)
        rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
    end
end