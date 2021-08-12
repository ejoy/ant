local ecs       = ...
local world     = ecs.world
local w         = world.w

local mc = import_package "ant.math".constant
local math3d    = require "math3d"
local default_comp 	= import_package "ant.general".default
local irq = world:interface "ant.render|irenderqueue"

local cmm = ecs.transform "camera_motion_transform"

function cmm.process_entity(e)
    local rc = e._rendercache
    local f = {}
    for k, v in pairs(e.frustum) do f[k] = v end
    rc.frustum = f
    rc.updir = math3d.ref(e.updir and math3d.vector(e.updir) or mc.YAXIS)
end

local ic = ecs.interface "camera"

local function find_camera(cameraeid)
    for v in w:select "eid:in camera:in" do
		if cameraeid == v.eid then
			return v.camera
		end
    end
end

ic.find_camera = find_camera

local defaultcamera = {
    eyepos  = {0, 0, 0, 1},
    viewdir = {0, 0, 1, 0},
    frustum = default_comp.frustum(),
    name = "default_camera",
}

function ic.create_entity(eid, info)
    info.updir = mc.YAXIS
    local srt = math3d.ref(info.transform and math3d.matrix(info.transform) or mc.IDENTITY_MAT)
    world:luaecs_create_entity {
        policy = {
            "ant.general|name",
            "ant.camera|camera",
            "ant.scene|scene_object",
        },
        data = {
            eid = eid,
            camera = {
                frustum = info.frustum,
                clip_range = info.clip_range,
                dof = info.dof,
                srt = srt,
            },
            name = info.name or "DEFAULT_CAMERA",
            scene = {
                srt = srt,
                updir = info.updir and math3d.ref(math3d.vector(info.updir)) or nil,
            }
        }
    }
end

function ic.create(info)
    info = info or defaultcamera
    local frustum = info.frustum
    if not frustum then
        frustum = default_comp.frustum()
    else
        local df = frustum.ortho and default_comp.ortho_frustum() or default_comp.frustum()
        for k ,v in pairs(df) do
            if not frustum[k] then
                frustum[k] = v
            end
        end
    end

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    local srt = math3d.ref(math3d.matrix(math3d.inverse(viewmat)))
    local eid = world:register_entity()
    world:luaecs_create_entity {
        policy = {
            "ant.general|name",
            "ant.camera|camera",
            "ant.scene|scene_object",
        },
        data = {
            eid = eid,
            camera = {
                frustum = frustum,
                clip_range = info.clip_range,
                dof = info.dof,
                srt = srt,
            },
            name = info.name or "DEFAULT_CAMERA",
            scene = {
                srt = srt,
                updir = info.updir and math3d.ref(math3d.vector(info.updir)) or nil,
            }
        }
    }
    return eid
end

local function bind_queue(cameraeid, queuename)
    irq.set_camera(queuename, cameraeid)
end

local function has_queue(qn)
    for _ in w:select(qn) do
        return true
    end
end

function ic.bind(eid, which_queue)
    if not has_queue(which_queue) then
        error(("not find queue:%s"):format(which_queue))
    end

    bind_queue(eid, which_queue)
end

function ic.controller(eid, ceid)
    local e = world[eid]
    local old_ceid = e.controller_eid

    if ceid == nil then
        return old_ceid
    end
    e.controller_eid = ceid
    world:pub{"camera_controller_changed", ceid, old_ceid}
end

ic.bind_queue = bind_queue

function ic.calc_viewmat(eid)
    --TODO
    local iobj_motion = world:interface "ant.objcontroller|obj_motion"
    return iobj_motion.calc_viewmat(eid)
end

function ic.calc_projmat(eid)
    local camera = find_camera(eid)
    return math3d.projmat(camera.frustum)
end

local function view_proj(worldmat, updir, frustum)
    local viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), updir)
    local projmat = math3d.projmat(frustum)
    return viewmat, projmat, math3d.mul(projmat, viewmat)
end

function ic.calc_viewproj(eid)
    local camera = find_camera(eid)
    local _, _, vp = view_proj(camera.srt, camera.updir, camera.frustum)
    return vp
end

function ic.get_frustum(eid)
    local camera = find_camera(eid)
    return camera.frustum
end

function ic.set_frustum(eid, frustum)
    local camera = find_camera(eid)
    camera.frustum = {}
    for k, v in pairs(frustum) do
        camera.frustum[k] = v
    end
    world:pub {"component_changed", "frustum", eid}
end

local function frustum_changed(eid, name, value)
    local camera = find_camera(eid)
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

function ic.set_frustum_aspect(eid, aspect)
    frustum_changed(eid, "aspect", aspect)
end

function ic.set_frustum_fov(eid, fov)
    frustum_changed(eid, "fov", fov)
end

function ic.set_frustum_near(eid, n)
    frustum_changed(eid, "n", n)
end

function ic.set_frustum_far(eid, f)
    frustum_changed(eid, "f", f)
end

local iom = world:interface "ant.objcontroller|obj_motion"
function ic.lookto(eid, ...)
    iom.lookto(eid, ...)
end

function ic.focus_obj(cameraeid, eid)
    local fe = world[eid]
    local aabb = fe._rendercache.aabb
    if aabb then
        local aabb_min, aabb_max= math3d.index(aabb, 1), math3d.index(aabb, 2)
        local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
        local nviewdir = math3d.sub(aabb_max, center)
        local viewdir = math3d.normalize(math3d.inverse(nviewdir))

        local pos = math3d.muladd(3, nviewdir, center)
        iom.lookto(cameraeid, pos, viewdir)
    end
end

function ic.set_dof_focus_obj(eid, focus_eid)
    local dof = world[eid]._dof
    dof.focus_eid = focus_eid
    world:pub{"component_changed", "dof", focus_eid, "focus_entity",}
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
    set_dof(world[eid], dof)
    world:pub{"component_changed", "dof", eid,}
end

local cameraview_sys = ecs.system "camera_view_system"

local function update_camera(cameraeid)
    if cameraeid == nil then    --TODO: need remove
        return
    end
    local camera = find_camera(cameraeid)
    if camera then
        local worldmat = camera.worldmat
        camera.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), camera.updir)
        camera.projmat = math3d.projmat(camera.frustum)
        camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
    end
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue camera_eid:in" do
        update_camera(v.camera_eid)
    end
    for v in w:select "blit_queue camera_eid:in" do
        update_camera(v.camera_eid)
    end
end

local bm = ecs.action "bind_camera"
function bm.init(prefab, idx, value)
    local eid
    if not value.camera_eid then
        eid = prefab[idx]
    else
        eid = prefab[idx][value.camera_eid]
    end
    
    ic.bind(eid, value.which)
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
