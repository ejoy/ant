local ecs = ...
local world = ecs.world
local w = world.w
local irq         = ecs.require "ant.render|renderqueue"
local utils   = require "common.utils"
local math3d  = require "math3d"

local camera_mgr = {}
local default_near_clip = 0.2
local default_far_clip  = 1000

function camera_mgr.set_second_camera(cameraref, show)
    irq.set_camera_from_queuename("second_view", cameraref)
    irq.set_visible("second_view", show)
end

function camera_mgr.on_target(eid, show)
    if not eid then return end
    local e <close> = world:entity(eid, "camera?in")
    if not e.camera then
        return
    end
    local qe = w:first("second_view render_target:in camera_ref?in")
    irq.set_camera(qe, eid)
    irq.set_visible("second_view", show)
end

local cameraidx = 0
local function gen_camera_name() cameraidx = cameraidx + 1 return "camera" .. cameraidx end


function camera_mgr.create_camera()
    local mc <close> = world:entity(irq.main_camera(), "camera:in scene:in")
    local main_frustum = mc.camera.frustum
    local srt = mc.scene
    local template = {
        policy = {
            "ant.camera|camera",
            "ant.camera|exposure"
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
            scene = {
                r = math3d.tovalue(srt.r),
                t = {math3d.index(srt.t, 1, 2, 3)},
                updir   = {0, 1, 0, 0},
            },
            exposure = {
				type 			= "manual",
				aperture 		= 16.0,
				shutter_speed 	= 0.008,
				ISO 			= 100,
			}
        },
        tag = {
            gen_camera_name()
        }
    }
    return world:create_entity(utils.deep_copy(template)), template
end

function camera_mgr.clear()
    irq.set_visible("second_view", false)
end

return camera_mgr
