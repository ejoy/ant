local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local defcomp 	= import_package "ant.general".default

local ic = ecs.interface "icamera"

local function find_camera(camera_ref)
    w:sync("camera:in", camera_ref)
    return camera_ref.camera
end

ic.find_camera = find_camera

-- local FStops<const> = {
--     "f/1.8", "f/2.0", "f/2.2", "f/2.5", "f/2.8", "f/3.2", "f/3.5", "f/4.0",
--     "f/4.5", "f/5.0", "f/5.6", "f/6.3", "f/7.1", "f/8.0", "f/9.0", "f/10.0",
--     "f/11.0", "f/13.0", "f/14.0", "f/16.0", "f/18.0", "f/20.0", "f/22.0",
-- }

local defaultcamera<const> = {
    name = "default_camera",
    eyepos  = {0, 0, 0, 1},
    viewdir = {0, 0, 1, 0},
    frustum = defcomp.frustum(),
    dof     = {},
    exposure= {
        type            = "Auto",  --Auto, Manaual, SBS, SOS, only support Auto and Manual right now
        ManualExposure  = -16.0,
        ApertureSize    = 16.0, --mean f/16.0
        ISO             = 100.0,
        ShutterSpeed    = 1.0/60.0,
        AutoExposureKey = 0.115,
        AdaptaionRate   = 0.5,
        --DOF
        FilmSize        = 35.0, --unit is: mm
        FocalLength     = 35.0, --unit is: mm, dof
        FocusDistance   = 10.0, --unit is: m
        NumBlades       = 5,
    },
}

function ic.create(info)
    info = info or defaultcamera
    local frustum = info.frustum
    if not frustum then
        frustum = defcomp.frustum()
    else
        local df = frustum.ortho and defcomp.ortho_frustum() or defcomp.frustum()
        for k ,v in pairs(df) do
            if not frustum[k] then
                frustum[k] = v
            end
        end
    end

    return ecs.create_entity {
        policy = {
            "ant.general|name",
            "ant.camera|camera",
        },
        data = {
            camera = {
                reference = true,
                eyepos  = assert(info.eyepos),
                viewdir = assert(info.viewdir),
                updir   = assert(info.updir),
                frustum = frustum,
                clip_range = info.clip_range,
                dof     = info.dof,
                -- exposure = {
                --     type = 
                -- },
            },
            name = info.name or "DEFAULT_CAMERA",
        }
    }
end

function ic.calc_viewmat(cameraref)
    w:sync("scene:in", cameraref)
    local scene = cameraref.scene
    local srt = scene.srt
    return math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
end

function ic.calc_projmat(cameraref)
    local camera = find_camera(cameraref)
    return math3d.projmat(camera.frustum)
end

function ic.world_to_screen(world_pos)
    local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
    local vp = ic.calc_viewproj(mq.camera_ref)
    return mu.world_to_screen(vp, world_pos, mq.render_target.view_rect)
end

function ic.calc_viewproj(cameraref)
    local camera = find_camera(cameraref)
    local srt = camera.srt
    local viewmat = math3d.lookto(srt.t, math3d.todirection(srt.r), camera.updir)
    local projmat = math3d.projmat(camera.frustum)
    return math3d.mul(projmat, viewmat)
end

function ic.get_frustum(cameraref)
    local camera = find_camera(cameraref)
    if camera then
        return camera.frustum
    end
end

local function set_camera_changed(subcomp, cameraref)
    world:pub {"camera_changed", subcomp, cameraref}
end

function ic.set_frustum(cameraref, frustum)
    local camera = find_camera(cameraref)
    camera.frustum = {}
    for k, v in pairs(frustum) do
        camera.frustum[k] = v
    end
    set_camera_changed("frusutm", cameraref)
end

local function frustum_changed(cameraref, name, value)
    local camera = find_camera(cameraref)
    if camera == nil then
        return
    end
    local f = camera.frustum
    if f.ortho then
        error("ortho frustum can not set aspect")
    end
    if f.aspect then
        f[name] = value
        set_camera_changed("frustum", cameraref)
    else
        error("Not implement")
    end
end

function ic.set_frustum_aspect(cameraref, aspect)
    frustum_changed(cameraref, "aspect", aspect)
end

function ic.set_frustum_fov(cameraref, fov)
    frustum_changed(cameraref, "fov", fov)
end

function ic.set_frustum_near(cameraref, n)
    frustum_changed(cameraref, "n", n)
end

function ic.set_frustum_far(cameraref, f)
    frustum_changed(cameraref, "f", f)
end

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
function ic.lookto(cameraref, ...)
    iom.lookto(cameraref, ...)
end

function ic.focus_obj(camera_ref, e)
    w:sync("render_object:in", e)
    local aabb = e.render_object.aabb
    if aabb then
        local aabb_min, aabb_max= math3d.index(aabb, 1), math3d.index(aabb, 2)
        local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
        local nviewdir = math3d.sub(aabb_max, center)
        local viewdir = math3d.normalize(math3d.inverse(nviewdir))

        local pos = math3d.muladd(3, nviewdir, center)
        iom.lookto(camera_ref, pos, viewdir)
    end
end

local cameraview_sys = ecs.system "camera_view_system"

local function update_camera(camera_ref)
    local camera = find_camera(camera_ref)
    local worldmat = camera.worldmat
    local pos, dir = math3d.index(worldmat, 4, 3)
    camera.viewmat = math3d.lookto(pos, dir, camera.updir)
    camera.projmat = math3d.projmat(camera.frustum)
    camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue camera_ref:in" do
        update_camera(v.camera_ref)
    end
    for v in w:select "blit_queue camera_ref:in" do
        update_camera(v.camera_ref)
    end
end
