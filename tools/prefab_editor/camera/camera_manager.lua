local ecs = ...
local world = ecs.world
local w = world.w
local irq         = ecs.import.interface "ant.render|irenderqueue"
local utils   = require "common.utils"
local math3d  = require "math3d"

local camera_mgr = {}
local default_near_clip = 0.1
local default_far_clip  = 100

function camera_mgr.set_second_camera(cameraref, show)
    irq.set_camera("second_view", cameraref)
    irq.set_visible("second_view", show)
end

local cameraidx = 0
local function gen_camera_name() cameraidx = cameraidx + 1 return "camera" .. cameraidx end


function camera_mgr.create_camera()
    local mc = world:entity(irq.main_camera())
    local main_frustum = mc.camera.frustum
    local srt = mc.scene.srt
    local template = {
        policy = {
            "ant.general|name",
            "ant.general|tag",
            "ant.camera|camera",
        },
        data = {
            camera = {
                frustum = {
                    n = default_near_clip,
                    f = default_far_clip,
                    aspect = main_frustum.aspect,
                    fov = main_frustum.fov
                },
            },
            name = gen_camera_name(),
            scene = {
                srt = {
                    r = math3d.tovalue(srt.r),
                    t = {math3d.index(srt.t, 1, 2, 3)},
                },
                updir   = {0, 1, 0, 0},
            },
            tag = {"camera"},
        }
    }
    return ecs.create_entity(utils.deep_copy(template)), template
end

function camera_mgr.clear()
    irq.set_visible("second_view", false)
end

return camera_mgr
