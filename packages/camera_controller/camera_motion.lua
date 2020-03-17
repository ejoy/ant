local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local hwi = renderpkg.hwi
local cu = renderpkg.component

local icamera_moition = ecs.interface "camera_motion"

local function camera_component(cameraeid)
    local ce = world[cameraeid]
    if ce == nil then
        error(string.format("invalid camera:%d", cameraeid))
    end

    return ce.camera
end

function icamera_moition.target(cameraeid, locktype, lock_eid, offset)
    local camera = camera_component(cameraeid)
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
    lock_target.offset = math3d.ref()
    lock_target.offset.v = offset or mc.ZERO
end

function icamera_moition.move(cameraeid, delta_vec)
    local camera = camera_component(cameraeid)
    camera.eyepos.v = math3d.add(camera.eyepos, delta_vec)
end

function icamera_moition.move_along_axis(cameraeid, axis, delta)
    local c = camera_component(cameraeid)

    c.eyepos.v = math3d.muladd(axis, delta, c.eyepos)
end

function icamera_moition.move_along(cameraeid, delta_vec)
    local c = camera_component(cameraeid)
    local right, up = math3d.base_axes(c.viewdir)
    local x = math3d.muladd(right, delta_vec[1], c.eyepos)
    local y = math3d.muladd(up, delta_vec[2], x)
    c.eyepos.v = math3d.muladd(c.viewdir, delta_vec[3], y)
end

function icamera_moition.move_toward(cameraeid, where, delta)
    local c = camera_component(cameraeid)

    local axisdir
    if where == "z" or where == "forward" then
        axisdir = c.viewdir
    elseif where == "x" or where == "right" then
        local right = math3d.base_axes(c.viewdir)
        axisdir = right
    elseif where == "y" or where == "up" then
        local _, up = math3d.base_axes(c.viewdir)
        axisdir = up
    else
        error(string.format("invalid direction: x/right for camera right; y/up for camera up; z/forward for camera viewdir:%s", where))
    end

    c.eyepos.v = math3d.muladd(axisdir, delta, c.eyepos)
end

local halfpi<const> = math.pi * 0.5
local n_halfpi = -halfpi

local function rotate_vec(dir, rotateX, rotateY, threshold_around_x_axis)
    rotateX = rotateX or 0
    rotateY = rotateY or 0

    local radianX, radianY = math3d.dir2radian(dir)

    radianX = mu.limit(radianX + rotateX, n_halfpi + threshold_around_x_axis, halfpi - threshold_around_x_axis)
    radianY = radianY + rotateY

    local qx = math3d.quaternion{axis=mc.XAXIS, r=radianX}
    local qy = math3d.quaternion{axis=mc.YAXIS, r=radianY}

    local q = math3d.mul(qx, qy)
    return math3d.transform(q, mc.ZAXIS, 0)
end

function icamera_moition.rotate(cameraeid, rotateX, rotateY)
    if rotateX or rotateY then
        local camera = camera_component(cameraeid)
        camera.viewdir.v = rotate_vec(camera.viewdir, rotateX, rotateY)
    end
end

function icamera_moition.rotate_around_point(cameraeid, targetpt, distance, dx, dy, threshold_around_x_axis)
    local camera = camera_component(cameraeid)
    threshold_around_x_axis = threshold_around_x_axis or 0.002

    camera.viewdir.v = math3d.normalize(rotate_vec(camera.viewdir, dx, dy, threshold_around_x_axis))

    local dir = math3d.mul(camera.viewdir, distance)
    camera.eyepos.v = math3d.sub(targetpt, dir)

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
    local mq = world:singleton_entity "main_queue"
    local vp_rt = mq.render_target.viewport.rect
    return {w=vp_rt.w, h=vp_rt.h}
end

function icamera_moition.ray(cameraeid, pt2d, vp_size)
    local camera = camera_component(cameraeid)

    vp_size = vp_size or main_queue_viewport_size()

    local ndc2d = to_ndc(pt2d, vp_size)
    local ndc_near = {ndc2d[1], ndc2d[2], hwi.get_caps().homogeneousDepth and -1 or 0, 1}
    local ndc_far = {ndc2d[1], ndc2d[2], 1, 1}

    local viewproj = mu.view_proj(camera)
    local invviewproj = math3d.inverse(viewproj)
    local pt_near_WS = math3d.transformH(invviewproj, ndc_near, 1)
    local pt_far_WS = math3d.transformH(invviewproj, ndc_far, 1)

    local dir = math3d.normalize(math3d.sub(pt_far_WS, pt_near_WS))
    return {
        origin = math3d.totable(pt_near_WS),
        dir = math3d.totable(dir),
    }
end

function icamera_moition.focus_point(cameraeid, pt)
    local camera = camera_component(cameraeid)
	camera.viewdir.v = math3d.normalize(pt, camera.eyepos)
end

function icamera_moition.focus_obj(cameraeid, eid)
    local camera = camera_component(cameraeid)

	local entity = world[eid]
	local bounding = cu.entity_bounding(entity)
    if bounding then
        local aabb = bounding.aabb
        local center, extents = math3d.aabb_center_extents(aabb)
        local radius = math3d.length(extents) * 0.5
		camera.viewdir.v = math3d.normalize(math3d.sub(center, camera.eyepos))
        camera.eyepos.v = math3d.sub(center, math3d.mul(camera.viewdir, radius * 3.5))
    else
        icamera_moition.focus_point(cameraeid, entity.transform.srt.t)
	end
end