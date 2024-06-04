local ecs           = ...
local world         = ecs.world
local w             = world.w
local math3d        = require "math3d"

local iom           = ecs.require "ant.objcontroller|obj_motion"

local mathpkg       = import_package"ant.math"
local mc            = mathpkg.constant

local iwr           = ecs.require "ant.render|viewport.window_resize"
local timer         = ecs.require "ant.timer|timer_system"
--local irp           = ecs.require "ant.objcontroller|pickup.raypick"
local window        = import_package "ant.window"

local cmd = window.get_cmd()

local common = ecs.require "common"
common.init_system = cmd[1] or "animation_instances"

local create_instance = ecs.require "util".create_instance

local init_loader_sys   = ecs.system 'init_system'

function init_loader_sys:init()
    create_instance "/pkg/ant.test.features/assets/entities/light_directional.prefab"
    create_instance "/pkg/ant.test.features/assets/entities/sky_with_ibl.prefab"
end

local function init_camera()
    local mq = w:first "main_queue camera_ref:in"
    local ce<close> = world:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 10,-10)
    iom.set_position(ce, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    --iom.set_direction(ce, mc.XAXIS)
    iom.set_direction(ce, dir)
end

local function init_light()
    local dl = w:first "directional_light scene:update"
    if dl then
        --iom.set_direction(dl, math3d.vector(0.0, -1.0, 0.0, 0.0))
        --rotate x-axis pi/2, y-axis pi/2
        --iom.set_rotation(dl, math3d.quaternion{math.pi*0.75, math.pi*0.25, 0.0})
        iom.set_direction(dl, math3d.normalize(math3d.vector(-1.0, -1.0, -1.0, 0.0)))
        w:submit(dl)
    end
end

function init_loader_sys:init_world()
    init_camera()
    init_light()
end

local kb_mb = world:sub{"keyboard"}
local SWITCH
function init_loader_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        if press == 0 and key == 'X' then
            if SWITCH then
                iwr.set_resolution_limits(1280, 720)
            else
                iwr.set_resolution_limits(1920, 1080)
            end
            SWITCH = not SWITCH
        end
    end
end

function init_loader_sys:camera_usage()
    -- for _, _, state, x, y in mouse_mb:unpack() do
    --     local mq = w:first("main_queue render_target:in camera_ref:in")
    --     local ce = world:entity(mq.camera_ref, "camera:in")
    --     local camera = ce.camera
    --     local vpmat = camera.viewprojmat
    
    --     local vr = mq.render_target.view_rect
    --     local nx, ny = mu.remap_xy(x, y, vr.ratio)
    --     local ndcpt = mu.pt2D_to_NDC({nx, ny}, vr)
    --     ndcpt[3] = 0
    --     local p0 = mu.ndc_to_world(vpmat, ndcpt)
    --     ndcpt[3] = 1
    --     local p1 = mu.ndc_to_world(vpmat, ndcpt)
    
    --     local ray = {o = p0, d = math3d.sub(p0, p1)}
    
    --     local plane = math3d.vector(0, 1, 0, 0)
    --     local t, p = math3d.plane_ray(ray.o, ray.d, plane, true)
        
    --     print("click:", x, y, math3d.tostring(r), "view_rect:", vr.x, vr.y, vr.w, vr.h)
    -- end
end