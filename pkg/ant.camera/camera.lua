local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc    = mathpkg.constant

local defcomp 	= import_package "ant.general".default
local iom = ecs.require "ant.objcontroller|obj_motion"

local INV_Z<const> = true
local INF_F<const> = true

local ic = {}

local function def_frustum(f)
    if not f then
        return defcomp.frustum()
    end

    local df = f.ortho and defcomp.ortho_frustum() or defcomp.frustum()
    for k ,v in pairs(df) do
        if not f[k] then
            f[k] = v
        end
    end
    return f
end

function ic.create(info, onready)
    info = info or {}
    local frustum = def_frustum(info.frustum)
    local policy = {
        "ant.camera|camera",
    }

    local exposure = info.exposure
    if exposure then
        policy[#policy+1] = "ant.camera|exposure"
    end

    return world:create_entity {
        policy = policy,
        data = {
            scene = {
                r = info.viewdir and math3d.ref(math3d.torotation(math3d.vector(info.viewdir))) or mc.IDENTITY_QUAT,
                t = info.eyepos or mc.ZERO_PT,
                updir = info.updir or mc.YAXIS,
            },
            exposure = exposure,
            camera = {
                frustum = frustum,
                clip_range = info.clip_range,
                dof     = info.dof,
            },
            camera_depend = info.camera_depend,
            on_ready = onready,
        },
    }
end


function ic.calc_viewmat(ce)
    w:extend(ce, "scene:in")
    local scene = ce.scene
    local srt = scene
    return math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
end

function ic.calc_projmat(ce)
    w:extend(ce, "camera:in")
    local camera = ce.camera
    return math3d.projmat(camera.frustum)
end

function ic.calc_viewproj(ce)
    w:extend(ce, "camera:in scene:in")
    local scene = ce.scene
    local srt = scene
    local viewmat = math3d.lookto(srt.t, math3d.todirection(srt.r), scene.updir)
    local projmat = math3d.projmat(ce.camera.frustum)
    return math3d.mul(projmat, viewmat)
end

function ic.get_frustum(ce)
    w:extend(ce, "camera:in")
    return ce.camera.frustum
end

local function mark_camera_changed(ce, changed)
    w:extend(ce, "camera_changed?out")
    ce.camera_changed = changed
    w:submit(ce)
end

function ic.set_frustum(ce, frustum)
    w:extend(ce, "camera:in")
    local camera = ce.camera
    camera.frustum = {}
    for k, v in pairs(frustum) do
        camera.frustum[k] = v
    end
    mark_camera_changed(ce, true)
end

local function frustum_changed(ce, name, value)
    w:extend(ce, "camera:in")
    local camera = assert(ce.camera)
    local f = camera.frustum
    f[name] = value

    mark_camera_changed(ce, true)
end

function ic.set_frustum_aspect(ce, aspect)
    frustum_changed(ce, "aspect", aspect)
end

function ic.set_frustum_fov(ce, fov)
    frustum_changed(ce, "fov", fov)
end

function ic.set_frustum_near(ce, n)
    frustum_changed(ce, "n", n)
end

function ic.set_frustum_far(ce, f)
    frustum_changed(ce, "f", f)
end

function ic.update_frustum(ce, ww, hh)
    w:extend(ce, "camera:in")
    local f = ce.camera.frustum
    if not f.ortho then
        f.aspect = ww/hh
        mark_camera_changed(ce, true)
    end
end

function ic.lookto(ce, ...)
    iom.lookto(ce, ...)
end

function ic.focus_aabb(ce, aabb)
    local aabb_min, aabb_max= math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
    local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
    local nviewdir = math3d.sub(aabb_max, center)
    local viewdir = math3d.normalize(math3d.inverse(nviewdir))

    local pos = math3d.muladd(3, nviewdir, center)
    iom.lookto(ce, pos, viewdir)
end

function ic.focus_obj(ce, e)
    w:extend(e, "bounding:in")
    local aabb = e.bounding.scene_aabb
    if aabb then
        ic.focus_aabb(ce, aabb)
    end
end

local cameraview_sys = ecs.system "camera_view_system"

function cameraview_sys:start_frame()
    w:clear "camera_changed"
end

function cameraview_sys:entity_init()
    for e in w:select "INIT camera:in camera_changed?out" do
        local camera = e.camera
        camera.viewmat       = math3d.ref()
        camera.projmat       = math3d.ref()
        camera.infprojmat    = math3d.ref()
        camera.viewprojmat   = math3d.ref()

        e.camera_changed    = true
    end
end

local function update_camera(e)
    local camera = e.camera
    camera.viewmat.m     = math3d.inverse(e.scene.worldmat)
    camera.projmat.m     = math3d.projmat(camera.frustum, INV_Z)
    camera.infprojmat.m  = math3d.projmat(camera.frustum, INV_Z, INF_F)
    camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
end

local function merge_camera_changed()
    --w:filter("camera_changed", "camera scene_changed")
    for e in w:select "scene_changed camera camera_changed?out" do
        e.camera_changed = true
    end
end
function cameraview_sys:update_camera()
    merge_camera_changed()
    for e in w:select "camera_changed camera_depend:absent camera:in scene:in" do
        update_camera(e)
    end
end

return ic
