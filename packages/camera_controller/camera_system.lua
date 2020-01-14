local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local default_comp=renderpkg.default

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local ms = mathpkg.stack

local icamera_spawn = ecs.interface "camera_spawn"
local default_frustum = default_comp.frustum()

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

local imotion_camera = ecs.interface "motion_camera"
function imotion_camera.target(cameraeid, locktype, lock_eid, offset)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end

    local camera = ce.camera
    local lock_target = camera.lock_target
    if lock_target == nil then
        lock_target = {}
        camera.lock_target = lock_target
    end

    lock_target.type = locktype
    
    if world[lock_eid].transform == nil then
        error(string.format("camera lock target entity must have transform component"));
    end
    lock_target.target = lock_eid
    lock_target.offset = ms:ref "vector"(offset or mc.ZERO)
end

function imotion_camera.move(cameraeid, delta)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end
    local camera = ce.camera
    ms(camera.eyepos, camera.eyepos, delta, "+=")
end

function imotion_camera.rotate(cameraeid, delta)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end
    local camera = ce.camera
    ms(camera.viewdir, 
    camera.viewdir, "D",    -- rotation = to_rotation(viewdir)
    delta, "+dn=")          -- rotation = rotation + value
                            -- viewdir = normalize(to_viewdir(rotation))
end

-- TODO: will move to another stage, this lock can do with any entity with transform component
local camerasys = ecs.system "camera_system"
function camerasys:lock_target()
    for _, eid in world:each "camera" do
        local camera = world[eid].camera
        local lock_target = camera.lock_target
        if lock_target then
            local locktype = lock_target.type
            if locktype == "move" then
                local targetentity = world[lock_target.target]
                local transform = targetentity.transform
                ms(camera.eyepos, transform.t, lock_target.offset, "+=")
            elseif locktype == "rotate" then
                local targetentity = world[lock_target.target]
                local transform = targetentity.transform

                local eyepos = camera.eyepos
                local targetpos = transform.t
                ms(camera.viewdir, targetpos, eyepos, "-n=")
            else
                error(string.format("not support locktype:%s", locktype))
            end
        end
    end
end