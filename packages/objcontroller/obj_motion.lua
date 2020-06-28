local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local ie = world:interface "ant.render|entity"
local iobj_motion = ecs.interface "obj_motion"

function iobj_motion.get_position(eid)
    local rc = world[eid]._rendercache
    return math3d.index(rc.srt, 4)
end

function iobj_motion.set_position(eid, pos)
    local rc = world[eid]._rendercache
    rc.srt.t = pos
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.get_direction(eid)
    local rc = world[eid]._rendercache
    return math3d.index(rc.srt, 3)
end

function iobj_motion.set_direction(eid, dir)
    local rc = world[eid]._rendercache
    rc.srt.r = math3d.torotation(dir)
    
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.srt(eid)
    return world[eid]._rendercache.srt
end

function iobj_motion.worldmat(eid)
    return world[eid]._rendercache.worldmat
end

function iobj_motion.lookto(eid, eyepos, viewdir, updir)
    local rc = world[eid]._rendercache
    rc.srt.id = math3d.inverse_fast(math3d.lookto(eyepos, viewdir, updir))
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.move(eid, delta_vec)
    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.add(p, delta_vec))
end

function iobj_motion.move_along_axis(eid, axis, delta)
    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.muladd(axis, delta, p))
end

function iobj_motion.move_along(eid, delta_vec)
    local dir = iobj_motion.get_direction(eid)
    local pos = iobj_motion.get_position(eid)

    local right, up = math3d.base_axes(dir)
    local x = math3d.muladd(right, delta_vec[1], pos)
    local y = math3d.muladd(up, delta_vec[2], x)
    iobj_motion.set_position(eid, math3d.muladd(dir, delta_vec[3], y))
end

function iobj_motion.move_toward(eid, where, delta)
    local viewdir = iobj_motion.get_direction(eid)
    local axisdir
    if where == "z" or where == "forward" then
        axisdir = viewdir
    elseif where == "x" or where == "right" then
        local right = math3d.base_axes(viewdir)
        axisdir = right
    elseif where == "y" or where == "up" then
        local _, up = math3d.base_axes(viewdir)
        axisdir = up
    else
        error(string.format("invalid direction: x/right for camera right; y/up for camera up; z/forward for camera viewdir:%s", where))
    end

    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.muladd(axisdir, delta, p))
end

--TODO: should not modify component directly
function iobj_motion.set_lock_target(eid, lt)
    local nlt = {}; for k, v in pairs(lt) do nlt[k] = v end
    world[eid]._rendercache.lock_target = nlt
    world:pub{"component_changed", "lock_target", eid}
end

local halfpi<const> = math.pi * 0.5
local n_halfpi = -halfpi

local function rotate_vec(dir, rotateX, rotateY, threshold_around_x_axis)
    rotateX = rotateX or 0
    rotateY = rotateY or 0

    threshold_around_x_axis = threshold_around_x_axis or 10e-6

    local radianX, radianY = math3d.dir2radian(dir)

    radianX = mu.limit(radianX + rotateX, n_halfpi + threshold_around_x_axis, halfpi - threshold_around_x_axis)
    radianY = radianY + rotateY

    local qx = math3d.quaternion{axis=mc.XAXIS, r=radianX}
    local qy = math3d.quaternion{axis=mc.YAXIS, r=radianY}

    local q = math3d.mul(qy, qx)
    return math3d.transform(q, mc.ZAXIS, 0)
end

function iobj_motion.rotate(eid, rotateX, rotateY)
    if rotateX or rotateY then
        iobj_motion.set_direction(eid, rotate_vec(iobj_motion.get_position(eid), rotateX, rotateY))
    end
end

function iobj_motion.rotate_around_point(eid, targetpt, distance, dx, dy, threshold_around_x_axis)
    threshold_around_x_axis = threshold_around_x_axis or 0.002

    local dir = iobj_motion.get_direction(eid)
    iobj_motion.lookto(eid,
        math3d.sub(targetpt, math3d.mul(dir, distance)),
        math3d.normalize(rotate_vec(dir, dx, dy, threshold_around_x_axis)))
end

function iobj_motion.focus_point(eid, pt)
	iobj_motion.set_direction(eid, math3d.normalize(math3d.sub(pt, iobj_motion.get_position(eid))))
end

function iobj_motion.focus_obj(eid, foucseid)
	local bounding = ie.entity_bounding(foucseid)
    if bounding then
        local aabb = bounding.aabb
        local center, extents = math3d.aabb_center_extents(aabb)
        local radius = math3d.length(extents) * 0.5
        
        local dir = math3d.normalize(math3d.sub(center, iobj_motion.get_position(eid)))
        iobj_motion.lookto(eid, dir, math3d.sub(center, math3d.mul(dir, radius * 3.5)))
    else
        local wm = iobj_motion.calc_worldmat(foucseid)
        iobj_motion.focus_point(eid, math3d.index(wm, 4))
	end
end

local function main_queue_viewport_size()
    local mq = world:singleton_entity "main_queue"
    local vp_rt = mq.render_target.viewport.rect
    return {w=vp_rt.w, h=vp_rt.h}
end

function iobj_motion.ray(eid, pt2d, vp_size)
    vp_size = vp_size or main_queue_viewport_size()

    local ndc_near, ndc_far = mu.NDC_near_far_pt(mu.pt2D_to_NDC(pt2d, vp_size))

    local viewproj = iobj_motion.viewproj(eid)
    local invviewproj = math3d.inverse(viewproj)
    local pt_near_WS = math3d.transformH(invviewproj, ndc_near, 1)
    local pt_far_WS = math3d.transformH(invviewproj, ndc_far, 1)

    local dir = math3d.normalize(math3d.sub(pt_far_WS, pt_near_WS))
    return {
        origin = pt_near_WS,
        dir = dir,
    }
end

local function calc_worldmat(eid, c_mt)
	local srt = itransform.srt(eid)
	local wm = c_mt and math3d.mul(srt, c_mt) or math3d.matrix(srt)
	local e = world[eid]
	if e.parent then
		return calc_worldmat(e.parent, wm)
	end
	return wm
end

function iobj_motion.calc_worldmat(eid)
    return calc_worldmat(eid)
end