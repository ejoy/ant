local ecs = ...
local world = ecs.world
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local defaultcomp = require "components.default"

local m = ecs.interface "camera"

function m.create(info)
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

    local locktarget = info.locktarget

    local policy = {
        "ant.render|camera",
        "ant.general|name",
    }

    if locktarget then
        policy[#policy+1] = "ant.objcontroller|camera_lock"
    end

    local camera_data = {
        type    = info.type     or "",
        eyepos  = world.component "vector"(info.eyepos   or mc.T_ZERO_PT),
        viewdir = world.component "vector"(info.viewdir  or mc.T_ZAXIS),
        updir   = world.component "vector"(info.updir    or mc.T_YAXIS),
        frustum = frustum,
    }
    return world:create_entity {
        policy = policy,
        data = {
            camera = camera_data,
            name = info.name or "DEFAULT_CAMERA",
            lock_target = locktarget,
        }
    }
end

function m.bind(id, which_queue)
    local q = world:singleton_entity(which_queue)
    if q == nil then
        error(string.format("not find queue:%s", which_queue))
    end
    q.camera_eid = id
    local vr = q.render_target.viewport.rect
    local camera = world[id]
    camera.camera.frustum.aspect = vr.w / vr.h
end

function m.get(id)
    return world[id].camera
end
