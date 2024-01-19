local ecs           = ...
local world         = ecs.world
local w             = world.w
local math3d        = require "math3d"

local iom           = ecs.require "ant.objcontroller|obj_motion"

local mathpkg       = import_package"ant.math"
local mc            = mathpkg.constant

local common = ecs.require "common"
common.init_system = "shadow"

local create_instance = ecs.require "util".create_instance

local init_loader_sys   = ecs.system 'init_system'

function init_loader_sys:init()
    create_instance "/pkg/ant.test.features/assets/entities/light.prefab"
end

local function init_camera()
    local mq = w:first "main_queue camera_ref:in"
    local eyepos = math3d.vector(0, 5, -5)
    local camera_ref<close> = world:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(mc.ZERO_PT, eyepos))
    iom.set_direction(camera_ref, dir)
end

local function init_light()
    local dl = w:first "directional_light scene:update"
    iom.set_direction(dl, math3d.vector(0.0, -1.0, 0.0, 0.0))
    w:submit(dl)
end

function init_loader_sys:init_world()
    init_camera()
    --init_light()
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
    --     local r = math3d.muladd(ray.d, math3d.plane_ray(ray.o, ray.d, plane), ray.o)
        
    --     print("click:", x, y, math3d.tostring(r), "view_rect:", vr.x, vr.y, vr.w, vr.h)
    -- end
end