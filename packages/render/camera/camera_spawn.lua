local ecs       = ...
local world     = ecs.world
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local math3d    = require "math3d"
local defaultcomp = require "components.default"

local cm = ecs.transform "camera_transform"

function cm.process_entity(e)
    local rc = e._rendercache
    local f = {}
    for k, v in pairs(e.frustum) do f[k] = v end
    rc.frustum = f

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
    local default_frustum = defaultcomp.frustum()
    if not frustum then
        frustum = default_frustum
    else
        for k ,v in pairs(default_frustum) do
            if not frustum[k] then
                frustum[k] = v
            end
        end
    end

    local policy = {
        "ant.render|camera",
        "ant.general|name",
    }

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    return world:create_entity {
        policy = policy,
        data = {
            transform   = math3d.ref(math3d.inverse_fast(viewmat)),
            frustum     = frustum,
            lock_target = info.locktarget,
            name        = info.name or "DEFAULT_CAMERA",
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
    local vr = q.render_target.viewport.rect
    ic.set_frustum_aspect(eid, vr.w / vr.h)
end

function ic.viewmat(eid)
    return world[eid]._rendercache.viewmat
end

function ic.projmat(eid)
    return world[eid]._rendercache.projmat
end

function ic.viewproj(eid)
    return math3d.mul(world[eid]._rendercache.projmat, world[eid]._rendercache.viewmat)
end

function ic.get_frustum(eid)
    return world[eid]._rendercache.frustum
end

function ic.set_frustum(eid, frustum)
    local rc = world[eid]._rendercache
    for k, v in pairs(frustum) do rc.frustum[k] = v end
    world:pub {"camera_changed", "frustum", eid}
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
        world:pub {"camera_changed", "frustum", eid}
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
