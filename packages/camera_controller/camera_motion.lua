local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mc = mathpkg.constant

local icamera_moition = ecs.interface "camera_motion"
function icamera_moition.target(cameraeid, locktype, lock_eid, offset)
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

function icamera_moition.move(cameraeid, delta)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end
    local camera = ce.camera
    ms(camera.eyepos, camera.eyepos, delta, "+=")
end

function icamera_moition.rotate(cameraeid, delta)
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