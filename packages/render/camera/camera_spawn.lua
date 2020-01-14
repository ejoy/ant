local ecs = ...
local world = ecs.world
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local defautlcomp = require "components.default"

local icamera_spawn = ecs.interface "camera_spawn"
local default_frustum = defautlcomp.frustum()

function icamera_spawn.spawn(name, info)
    return world:create_entity {
        policy = {
            "ant.render|camera",
            "ant.render|name",
        },
        data = {
            camera = {
                type    = info.type     or "",
                eyepos  = info.eyepos   or mc.T_ZERO_PT,
                viewdir = info.viewdir  or mc.T_ZAXIS,
                updir   = info.updir    or mc.T_NXAXIS,
                frustum = info.frustum  or default_frustum,
            },
            name = name,
        }
    }
end

function icamera_spawn.bind(which_queue, cameraeid)
    local q = world:singleton_entity(which_queue)
    if q == nil then
        error(string.format("not find queue:%s", which_queue))
    end
    q.camera_eid = cameraeid
end