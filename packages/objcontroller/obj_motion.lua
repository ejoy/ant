local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local iobj_motion = ecs.interface "obj_motion"
local icamera = world:interface "ant.camera|camera"

function iobj_motion.get_position(eid)
    return math3d.index(world[eid]._rendercache.srt, 4)
end

function iobj_motion.set_position(eid, pos)
    world[eid]._rendercache.srt.t = pos
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.get_direction(eid)
    return math3d.index(world[eid]._rendercache.srt, 3)
end

function iobj_motion.set_direction(eid, dir)
    world[eid]._rendercache.srt.r = math3d.torotation(dir)
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.srt(eid)
    return world[eid]._rendercache.srt
end

function iobj_motion.set_srt(eid, srt)
    world[eid]._rendercache.srt.m = srt
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.set_view(eid, pos, dir)
    local srt = world[eid]._rendercache.srt
    local s = math3d.matrix_scale(srt)
    srt.m = math3d.matrix{s=s, r=math3d.torotation(dir), t=pos}
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.worldmat(eid)
    return world[eid]._rendercache.worldmat
end

function iobj_motion.lookto(eid, eyepos, viewdir, updir)
    local rc = world[eid]._rendercache
    rc.srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, updir))
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.move(eid, delta_vec)
    local srt = world[eid]._rendercache.srt
    local pos = math3d.add(math3d.index(srt, 4), delta_vec)
    iobj_motion.set_position(eid, pos)
end

function iobj_motion.move_along_axis(eid, axis, delta)
    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.muladd(axis, delta, p))
end

function iobj_motion.set_lock_target(eid, lt)
    local nlt = {}; for k, v in pairs(lt) do nlt[k] = v end
    world[eid]._rendercache.lock_target = nlt
    world:pub{"component_changed", "lock_target", eid}
end

local halfpi<const> = math.pi * 0.5

local function calc_rotation(srt, rotateX, rotateY, threshold)
    rotateX = rotateX or 0
    rotateY = rotateY or 0

    threshold = threshold or 10e-6

    local q = srt.r
    local nq = math3d.mul(math3d.mul(
        math3d.quaternion{axis=math3d.index(srt, 1), r=rotateX},
        math3d.quaternion{axis=math3d.index(srt, 2), r=rotateY}), q)

    local v = math3d.transform(nq, mc.ZAXIS, 0)
    
    if mu.iszero(math3d.dot(v, mc.NZAXIS), threshold) or mu.iszero(math3d.dot(v, mc.ZAXIS), threshold) then
        return q
    end

    return nq
end

function iobj_motion.rotate(eid, rotateX, rotateY)
    if rotateX or rotateY then
        local srt = world[eid]._rendercache.srt
        srt.r = calc_rotation(srt, rotateX, rotateY)
    end
end

function iobj_motion.rotate_around_point(eid, targetpt, distance, dx, dy, threshold)
    local srt = world[eid]._rendercache.srt
    local q = calc_rotation(srt, -dx, -dy, threshold)

    local dir = math3d.normalize(math3d.inverse(math3d.transform(q, mc.ZAXIS, 0)))
    local p = math3d.muladd(distance, dir, targetpt)
    local s = math3d.matrix_scale(srt)
    srt.m = math3d.matrix{s=s, r=q, t=p}
end

local function main_queue_viewport_size()
    local mq = world:singleton_entity "main_queue"
    local vp_rt = mq.render_target.viewport.rect
    return {w=vp_rt.w, h=vp_rt.h}
end

function iobj_motion.ray(eid, pt2d, vp_size)
    vp_size = vp_size or main_queue_viewport_size()

    local ndc_near, ndc_far = mu.NDC_near_far_pt(mu.pt2D_to_NDC(pt2d, vp_size))

    local viewproj = icamera.calc_viewproj(eid)
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
    local srt = world[eid]._rendercache.srt
    local wm
    if srt then
        wm = c_mt and math3d.mul(srt, c_mt) or math3d.matrix(srt)
    else
        wm = c_mt
    end

	local e = world[eid]
	if e.parent then
		return calc_worldmat(e.parent, wm)
	end
	return wm
end

function iobj_motion.calc_worldmat(eid)
    return calc_worldmat(eid)
end