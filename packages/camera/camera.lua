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

    local lt = e.lock_target
    if lt then
        local nlt = {}
        for k, v in pairs(lt) do
            nlt[k] = v
        end
        rc.lock_target = nlt
    end
end

local ic = ecs.interface "camera"

local defaultcamera = {
    eyepos  = {0, 0, 0, 1},
    viewdir = {0, 0, 1, 0},
    frustum = default_comp.frustum(),
    name = "default_camera",
}

function ic.create(info, v2)
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

    local policy = {
        "ant.camera|camera",
        "ant.general|name",
    }

    local dof = info.dof
    if dof then
        policy[#policy+1] = "ant.camera|dof"
    end

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    local ce = {
        policy = policy,
        data = {
            name        = info.name or "DEFAULT_CAMERA",
            transform   = math3d.inverse(viewmat),
            updir       = info.updir,
            lock_target = info.locktarget,
            frustum     = frustum,
            clip_range  = info.clip_range,
            scene_entity= true,
            camera      = true,
            dof         = dof,
        }
    }

    if v2 then
        world:luaecs_create_entity(ce)
        
    end
    return world:create_entity(ce)
end

local function bind_queue(cameraeid, qeid)
    irq.set_camera(qeid, cameraeid)
    local vr = irq.view_rect(qeid)
    ic.set_frustum_aspect(cameraeid, vr.w / vr.h)
end

function ic.bind(eid, which_queue)
    local qeid = world:singleton_entity_id(which_queue)
    if qeid == nil then
        error(string.format("not find queue:%s", which_queue))
    end

    bind_queue(eid, qeid)
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
    local rc = world[eid]._rendercache
    return math3d.lookto(math3d.index(rc.srt, 4), math3d.index(rc.srt, 3), rc.updir)
end

function ic.calc_projmat(eid)
    return math3d.projmat(world[eid]._rendercache.frustum)
end

local function view_proj(worldmat, updir, frustum)
    local viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), updir)
    local projmat = math3d.projmat(frustum)
    return viewmat, projmat, math3d.mul(projmat, viewmat)
end

function ic.calc_viewproj(eid)
    local rc = world[eid]._rendercache
    local _, _, vp = view_proj(rc.srt, rc.updir, rc.frustum)
    return vp
end

function ic.get_frustum(eid)
    return world[eid]._rendercache.frustum
end

function ic.set_frustum(eid, frustum)
    local rc = world[eid]._rendercache
    rc.frustum = {}
    for k, v in pairs(frustum) do rc.frustum[k] = v end
    world:pub {"component_changed", "frustum", eid}
end

function ic.set_updir(eid, updir)
    world[eid]._rendercache.updir.v = updir
    world:pub {"component_changed", "updir", eid}
end

local function frustum_changed(eid, name, value)
    local e = world[eid]
    local rc = e._rendercache
    local f = rc.frustum

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

local function update_camera(v)
    local rq = v.render_queue
    local camera = w:object("camera_node", rq.camera_id)
    local worldmat = camera.worldmat
    camera.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), camera.updir)
    camera.projmat = math3d.projmat(camera.frustum)
    camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)
end

function cameraview_sys:update_mainview_camera()
    for v in w:select "main_queue render_queue:in" do
        update_camera(v)
    end
    for v in w:select "blit_queue render_queue:in" do
        update_camera(v)
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
