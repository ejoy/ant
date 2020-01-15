local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mc = mathpkg.constant

local renderpkg = import_package "ant.render"
local hwi = renderpkg.hwi

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

local function to_ndc(pt2d, screensize)
    local screen_y = pt2d.y / screensize.h
    if not hwi.get_caps().originBottomLeft then
        screen_y = 1 - screen_y
    end

    return {
        (pt2d.x / screensize.w) * 2 - 1,
        (screen_y) * 2 - 1,
    }
end

function icamera_moition.ray(cameraeid, pt2d, screensize)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end

    screensize = screensize or world.args.fb_size

    local ndc2d = to_ndc(pt2d, screensize)
    local ndc_near = {ndc2d[1], ndc2d[2], hwi.get_caps().homogeneousDepth and -1 or 0}
    local ndc_far = {ndc2d[1], ndc2d[2], 1}

    local camera = ce.camera
    local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
    local pt_near_WS = ms(viewproj, "i", ndc_near, "*P")
    local pt_far_WS = ms(viewproj, "i", ndc_far, "*P")

    return {
        origin = ms(pt_near_WS, "T"),
        dir = ms(pt_far_WS, pt_near_WS, "-nT")
    }
end