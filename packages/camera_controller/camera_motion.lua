local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms, mc, mu = mathpkg.stack, mathpkg.constant, mathpkg.util

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

local halfpi<const> = math.pi * 0.5
local n_halfpi = -halfpi

function icamera_moition.rotate_around_point(cameraeid, targetpt, distance, dx, dy, threshold_around_x_axis)
    threshold_around_x_axis = threshold_around_x_axis or 0.002
    local camera = world[cameraeid].camera
    local radianX, radianY = ms:dir2radian(camera.viewdir)
    radianX = radianX + dx
    radianY = radianY + dy

    radianX = mu.limit(radianX, n_halfpi + threshold_around_x_axis, halfpi - threshold_around_x_axis)

    local qx = ms:quaternion(mc.XAXIS, radianX)
    local qy = ms:quaternion(mc.YAXIS, radianY)

    ms(camera.viewdir, qy, qx, "*", mc.ZAXIS, "*=")
    ms(camera.eyepos, targetpt, camera.viewdir, {distance}, "*-=")
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

local function main_queue_viewport_size()
    local mq = world:single_entity "main_queue"
    local vp_rt = mq.render_target.viewport.rect
    return {w=vp_rt.w, h=vp_rt.h}
end

function icamera_moition.ray(cameraeid, pt2d, vp_size)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end

    vp_size = vp_size or main_queue_viewport_size()

    local ndc2d = to_ndc(pt2d, vp_size)
    local ndc_near = {ndc2d[1], ndc2d[2], hwi.get_caps().homogeneousDepth and -1 or 0, 1}
    local ndc_far = {ndc2d[1], ndc2d[2], 1, 1}

    local camera = ce.camera
    local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
    local invviewproj = ms(viewproj, "iP")
    local pt_near_WS = ms(invviewproj, ndc_near, "%P")
    local pt_far_WS = ms(invviewproj, ndc_far, "%P")

    return {
        origin = ms(pt_near_WS, "T"),
        dir = ms(pt_far_WS, pt_near_WS, "-nT")
    }
end