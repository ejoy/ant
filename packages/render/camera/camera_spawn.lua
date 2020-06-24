local ecs       = ...
local world     = ecs.world
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local math3d    = require "math3d"
local defaultcomp = require "components.default"

local cm = ecs.transform "camera_transform"

function cm.process_entity(e)
    local rc = e._rendercache
    rc.viewmat = math3d.ref(math3d.transpose(rc.srt))
    rc.projmat = math3d.ref(math3d.projmat(e.frustum))
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

local ic_class = ecs.interface "camera"
local ic = world:interface "ant.render|camera"

function ic_class.create(info)
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
            transform   = math3d.ref(math3d.transpose(viewmat)),
            frustum     = frustum,
            lock_target = info.locktarget,
            name        = info.name or "DEFAULT_CAMERA",
        }
    }
end

function ic_class.bind(eid, which_queue)
    local q = world:singleton_entity(which_queue)
    if q == nil then
        error(string.format("not find queue:%s", which_queue))
    end
    q.camera_eid = eid
    local vr = q.render_target.viewport.rect
    ic.set_frustum_aspect(eid, vr.w / vr.h)
end

function ic_class.eyepos(eid)
    local rc = world[eid]._rendercache
    return math3d.index(rc.srt, 4)
end

function ic_class.viewdir(eid)
    local rc = world[eid]._rendercache
    return math3d.transform(rc.srt, mc.ZAXIS, 0)
end

function ic_class.viewmat(eid)
    return world[eid]._rendercache.viewmat
end

function ic_class.projmat(eid)
    return world[eid]._rendercache.projmat
end

function ic_class.viewproj(eid)
    return math3d.mul(world[eid]._rendercache.projmat, world[eid]._rendercache.viewmat)
end

function ic_class.get_frustum(eid)
    return world[eid]._rendercache.frustum
end

function ic_class.set_frustum(eid, frustum)
    local rc = world[eid]._rendercache
    rc.projmat.id = math3d.projmat(frustum)
    for k, v in pairs(frustum) do rc.frustum[k] = v end
    world:pub {"camera_changed", "frustum", eid}
end

function ic_class.set_eyepos(eid, pos)
    local rc = world[eid]._rendercache
    rc.srt.t = pos
    rc.viewmat.id = math3d.transpose(rc.srt)

    world:pub{"camcera_changed", "transform", eid}
end

function ic_class.lookto(eid, eyepos, viewdir, updir)
    updir = updir or mc.YAXIS
    local viewmat = math3d.lookto(eyepos, viewdir, updir)
    local rc = world[eid]._rendercache
    rc.srt.id = math3d.transpose(viewmat)
    rc.viewmat.id = viewmat

    world:pub{"camera_changed", "transform", eid}
end

function ic_class.set_viewdir(eid, viewdir)
    local rc = world[eid]._rendercache
    rc.srt.r = math3d.torotation(viewdir)
    rc.viewmat.id = math3d.transpose(rc.srt)
    world:pub{"camcera_changed", "transform", eid}
end

function ic_class.set_frustum_aspect(eid, aspect)
    local e = world[eid]
    local rc = e._rendercache
    local f = rc.frustum

    if f.ortho then
        error("ortho frustum can not set aspect")
    end
    
    if f.aspect then
        f.aspect = aspect
        rc.projmat.id = math3d.projmat(f)
        world:pub {"camera_changed", "frustum", eid}
    else
        error("Not implement")
    end 
end