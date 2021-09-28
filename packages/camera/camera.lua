local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"

local mc        = import_package "ant.math".constant
local defcomp 	= import_package "ant.general".default

local cmm = ecs.transform "camera_motion_transform"

function cmm.process_entity(e)
    local rc = e._rendercache
    local f = {}
    for k, v in pairs(e.frustum) do f[k] = v end
    rc.frustum = f
    rc.updir = math3d.ref(e.updir and math3d.vector(e.updir) or mc.YAXIS)
end

local ic = ecs.interface "camera"

local function find_camera(camera_ref)
    w:sync("camera:in", camera_ref)
    return camera_ref.camera
end

ic.find_camera = find_camera

local defaultcamera = {
    eyepos  = {0, 0, 0, 1},
    viewdir = {0, 0, 1, 0},
    frustum = defcomp.frustum(),
    name = "default_camera",
}

function ic.create_entity(_, info)
    info.updir = mc.YAXIS
    return ecs.create_entity {
        policy = {
            "ant.general|name",
            "ant.camera|camera",
        },
        data = {
            camera = {
                eyepos  = info.transform.t,
                viewdir = math3d.todirection(math3d.quaternion(info.transform.r)),
                updir   = info.updir,
                frustum = info.frustum,
                clip_range = info.clip_range,
                dof     = info.dof,
            },
            name = info.name or "DEFAULT_CAMERA",
        }
    }
end

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
                eyepos  = assert(info.eyepos),
                viewdir = assert(info.viewdir),
                updir   = assert(info.updir),
                frustum = frustum,
                clip_range = info.clip_range,
                dof     = info.dof,
            },
            name = info.name or "DEFAULT_CAMERA",
        }
    }
end

function ic.calc_viewmat(cameraref)
    --TODO
    local iobj_motion = ecs.import.interface "ant.objcontroller|obj_motion"
    return iobj_motion.calc_viewmat(cameraref)
end

function ic.calc_projmat(eid)
    local camera = find_camera(eid)
    return math3d.projmat(camera.frustum)
end

function ic.world_to_screen(world_pos)
    local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
    local vp = ic.calc_viewproj(mq.camera_ref)
	local proj_pos = math3d.totable(math3d.transformH(vp, world_pos, 1))
    local viewport = mq.render_target.view_rect
	return {(proj_pos[1] + 1) * viewport.w * 0.5, (1 - (proj_pos[2] + 1) * 0.5) * viewport.h, 0}
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

function ic.set_frustum(cameraref, frustum)
    local camera = find_camera(cameraref)
    camera.frustum = {}
    for k, v in pairs(frustum) do
        camera.frustum[k] = v
    end
    world:pub {"component_changed", "frustum", cameraref}
end

local function frustum_changed(eid, name, value)
    local camera = find_camera(eid)
    if camera == nil then
        return
    end
    local f = camera.frustum
    if f.ortho then
        error("ortho frustum can not set aspect")
    end
    if f.aspect then
        f[name] = value
        world:pub {"component_changed", "frustum", eid}
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

local iom = ecs.import.interface "ant.objcontroller|obj_motion"
function ic.lookto(eid, ...)
    iom.lookto(eid, ...)
end

function ic.focus_obj(camera_ref, eid)
    local fe = world[eid]
    local aabb = fe._rendercache.aabb
    if aabb then
        local aabb_min, aabb_max= math3d.index(aabb, 1), math3d.index(aabb, 2)
        local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
        local nviewdir = math3d.sub(aabb_max, center)
        local viewdir = math3d.normalize(math3d.inverse(nviewdir))

        local pos = math3d.muladd(3, nviewdir, center)
        iom.lookto(camera_ref, pos, viewdir)
    end
end

function ic.set_dof_focus_obj(eid, focus_eid)
    assert(false, "not implement new ecs camera")
    -- local dof = world[eid]._dof
    -- dof.focus_eid = focus_eid
    -- world:pub{"component_changed", "dof", focus_eid, "focus_entity",}
end

local function set_dof(e, dof)
    e._dof = {
        aperture_fstop      = dof.aperture_fstop,
        aperture_blades     = dof.aperture_blades,
        aperture_rotation   = dof.aperture_rotation,
        aperture_ratio      = dof.aperture_ratio,
        sensor_size         = dof.sensor_size,
        focus_distance      = dof.focus_distance,
        focal_len           = dof.focal_len,
        focuseid            = dof.focuseid,
        enable              = dof.enable,
    }
end

function ic.set_dof(eid, dof)
    assert(false, "not implement new ecs camera")
    -- set_dof(world[eid], dof)
    -- world:pub{"component_changed", "dof", eid,}
end

local cameraview_sys = ecs.system "camera_view_system"

local function update_camera(camera_ref)
    if camera_ref == nil then    --TODO: need remove
        return
    end
    local camera = find_camera(camera_ref)
    if camera then
        local worldmat = camera.worldmat
        local pos, dir = math3d.index(worldmat, 4, 3)
        camera.viewmat = math3d.lookto(pos, dir, camera.updir)
        camera.projmat = math3d.projmat(camera.frustum)
        camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
    end
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue camera_ref:in" do
        update_camera(v.camera_ref)
    end
    for v in w:select "blit_queue camera_ref:in" do
        update_camera(v.camera_ref)
    end
end

local dof_trans = ecs.transform "dof_transform"
function dof_trans.process_entity(e)
    local dof = e.dof
    set_dof(e, dof)
end

local dof_focus = ecs.action "dof_focus_obj"
function dof_focus:init(prefab, idx, value)
    local eid = prefab[idx]
    local focuseid = prefab[value]
    ic.focus_obj(eid, focuseid)
end
