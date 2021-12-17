local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

local defcomp 	= import_package "ant.general".default

local ic = ecs.interface "icamera"

local function find_camera(camera_ref)
    w:sync("camera:in", camera_ref)
    return camera_ref.camera
end

ic.find_camera = find_camera

local defaultcamera<const> = {
    name = "default_camera",
    eyepos  = mc.ZERO_PT,
    viewdir = mc.ZAXIS,
    updir   = mc.YAXIS,
    frustum = defcomp.frustum(),
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

    local policy = {
        "ant.general|name",
        "ant.camera|camera",
    }

    local exposure = info.exposure
    if exposure then
        policy[#policy+1] = "ant.camera|exposure"
    end

    local viewdir = info.viewdir or defaultcamera.viewdir
    local eyepos = info.eyepos or defaultcamera.eyepos
    local updir = info.updir or defaultcamera.updir

    return ecs.create_entity {
        policy = policy,
        data = {
            scene = {
                srt = {
                    r = math3d.torotation(math3d.vector(viewdir)),
                    t = eyepos,
                },
                updir = updir,
            },
            reference = true,
            exposure = exposure,
            camera = {
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
    return mu.world_to_screen(vp, mq.render_target.view_rect, world_pos)
end

function ic.calc_viewproj(cameraref)
    w:sync("camera:in scene:in", cameraref)
    
    local scene = cameraref.scene
    local srt = scene.srt
    local viewmat = math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
    local projmat = math3d.projmat(cameraref.camera.frustum)
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
    w:sync("camera:in scene:in", camera_ref)
    local camera = camera_ref.camera
    local worldmat = camera_ref.scene._worldmat
    local pos, dir = math3d.index(worldmat, 4, 3)
    camera.viewmat = math3d.lookto(pos, dir, camera.updir)
    camera.projmat = math3d.projmat(camera.frustum)
    camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue camera_ref:in" do
        update_camera(v.camera_ref)
    end
end
