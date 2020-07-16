local ecs       = ...
local world     = ecs.world

local mc = import_package "ant.math".constant
local math3d    = require "math3d"
local default_comp 	= import_package "ant.general".default

local cm = ecs.transform "camera_transform"

function cm.process_entity(e)
    local rc = e._rendercache
    local f = {}
    for k, v in pairs(e.frustum) do f[k] = v end
    rc.frustum = f
    rc.updir = math3d.ref(e.updir or mc.YAXIS)
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

function ic.create(info)
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

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    return world:create_entity {
        policy = policy,
        data = {
            transform   = math3d.ref(math3d.inverse(viewmat)),
            frustum     = frustum,
            lock_target = info.locktarget,
            updir       = info.updir,
            name        = info.name or "DEFAULT_CAMERA",
            scene_entity= true,
            camera      = true,
        }
    }
end

function ic.bind(eid, which_queue)
    local q = world:singleton_entity(which_queue)
    if q == nil then
        error(string.format("not find queue:%s", which_queue))
    end
    q.camera_eid = eid
    local vr = q.render_target.view_rect
    ic.set_frustum_aspect(eid, vr.w / vr.h)
end

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

local cameraview_sys = ecs.system "camera_view_system"

local function update_camera(eid)
    local rc = world[eid]._rendercache
    local worldmat = rc.worldmat
    rc.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), rc.updir)
    rc.projmat = math3d.projmat(rc.frustum)
    rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
end

function cameraview_sys:update_mainview_camera()
    local mq = world:singleton_entity "main_queue"
    update_camera(mq.camera_eid)

    local bq = world:singleton_entity "blit_queue"
    update_camera(bq.camera_eid)
end

local bm = ecs.action "bind_camera"
function bm.init(prefab, idx, value)
    local eid = prefab[idx][1]
    ic.bind(eid, value)
end