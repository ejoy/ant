local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mu     = import_package "ant.math".util
local mc     = import_package "ant.math".constant

local iobj_motion = ecs.interface "obj_motion"
local icamera = world:interface "ant.camera|camera"

function iobj_motion.get_position(eid)
    return math3d.index(world[eid]._rendercache.srt, 4)
end

function iobj_motion.set_position(eid, pos)
    world[eid]._rendercache.srt[4] = pos
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.get_direction(eid)
    return math3d.index(world[eid]._rendercache.srt, 3)
end

function iobj_motion.set_direction(eid, dir)
    local e = world[eid]
    local rc = e._rendercache
    local srt = rc.srt
    if rc.updir then
        srt.id = math3d.inverse(math3d.lookto(math3d.index(srt, 4), dir, rc.updir))
    else
        srt.r = math3d.torotation(dir)
    end
    
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.get_updir(eid, dir)
    local e = world[eid]
    local rc = e._rendercache
    local srt = rc.srt
    return math3d.index(srt, 2)
end

function iobj_motion.srt(eid)
    if world[eid]._rendercache then return world[eid]._rendercache.srt end
end

function iobj_motion.set_srt(eid, srt)
    world[eid]._rendercache.srt.m = srt
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.set_view(eid, pos, dir, updir)
    local e = world[eid]
    local rc = e._rendercache
    local srt = rc.srt
    if rc.updir then
        srt.id = math3d.inverse(math3d.lookto(pos, dir, updir or rc.updir))
    else
        local s = math3d.matrix_scale(srt)
        srt.id = math3d.matrix{s=s, r=math3d.torotation(dir), t=pos}
    end

    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.set_scale_no_check(eid, scale)
    world[eid]._rendercache.srt.s = scale
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.set_scale(eid, scale)
    if type(scale) == "number" then
        iobj_motion.set_scale_no_check(eid, {scale, scale, scale})
    end
    iobj_motion.set_scale_no_check(eid, scale)
end

function iobj_motion.get_scale(eid)
    return math3d.matrix_scale(world[eid]._rendercache.srt)
end

function iobj_motion.set_rotation(eid, rot)
    local e = world[eid]
    local rc = e._rendercache
    local srt = rc.srt
    if rc.updir then
        local viewdir = math3d.todirection(rot)
        srt.id = math3d.inverse(math3d.lookto(math3d.index(srt, 4), viewdir, rc.updir))
    else
        srt.r = rot
    end
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.get_rotation(eid)
    return world[eid]._rendercache.srt.r
end

function iobj_motion.worldmat(eid)
    return world[eid]._rendercache.worldmat
end

function iobj_motion.lookto(eid, eyepos, viewdir, updir)
    local e = world[eid]
    local rc = e._rendercache
    if updir then
        if rc.updir == nil then
            rc.updir = math3d.ref(math3d.vector(0, 1, 0, 0))
        end
        rc.updir.v = updir
    end
    rc.srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, updir))
    world:pub{"component_changed", "transform", eid}
end

function iobj_motion.move_delta(eid, delta_vec)
    local srt = world[eid]._rendercache.srt
    local pos = math3d.add(math3d.index(srt, 4), delta_vec)
    iobj_motion.set_position(eid, pos)
end

function iobj_motion.move_along_axis(eid, axis, delta)
    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.muladd(axis, delta, p))
end

function iobj_motion.move(eid, v)
    local srt = world[eid]._rendercache.srt
    local p = math3d.index(srt, 4)
    for i=1, 3 do
        p = math3d.muladd(v[i], math3d.index(srt, i), p)
    end
    iobj_motion.set_position(eid, p)
end

function iobj_motion.move_forward(eid, v)
    local srt = world[eid]._rendercache.srt
    local f = math3d.normalize(math3d.index(srt, 3))
    iobj_motion.move_along_axis(eid, f, v)
end

function iobj_motion.set_lock_target(eid, lt)
    local nlt = {}; for k, v in pairs(lt) do nlt[k] = v end
    world[eid]._rendercache.lock_target = nlt
    world:pub{"component_changed", "lock_target", eid}
end

local function add_rotation(srt, rotateX, rotateY, threshold)
    rotateX = rotateX or 0
    rotateY = rotateY or 0

    threshold = threshold or 10e-6

    local nq = math3d.mul(
        math3d.quaternion{axis=math3d.index(srt, 1), r=rotateX},
        math3d.quaternion{axis=math3d.index(srt, 2), r=rotateY})

    local v = math3d.transform(nq, mc.ZAXIS, 0)
    
    if mu.iszero(math3d.dot(v, mc.NZAXIS), threshold) or mu.iszero(math3d.dot(v, mc.ZAXIS), threshold) then
        return srt
    end

    return math3d.mul(math3d.matrix{r=nq}, srt)
end

local function rotate_forword_vector(srt, rx, ry)
    local forward = srt[3]

    local nq = math3d.mul(
        math3d.quaternion{axis=math3d.index(srt, 1), r=rx},
        math3d.quaternion{axis=math3d.index(srt, 2), r=ry})
    
    return math3d.transform(nq, forward, 0)
end

function iobj_motion.rotate_forward_vector(eid, rotateX, rotateY)
    if rotateX or rotateY then
        local rc = world[eid]._rendercache
        local srt = rc.srt
        local eyepos = srt[4]
        local viewdir = rotate_forword_vector(srt, rotateX, rotateY)
        if rc.updir then
            srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, rc.updir))
        else
            local xaxis = math3d.isequal(viewdir, mc.ZAXIS) and mc.XAXIS or math3d.cross(viewdir, mc.ZAXIS)
            local yaxis = math3d.cross(viewdir, xaxis)
            srt[1], srt[2], srt[3] = xaxis, yaxis, viewdir
        end

        world:pub{"component_changed", "transform", eid}
    end
end

function iobj_motion.rotate_around_point2(eid, viewpt, dx, dy, distance)
    local srt = world[eid]._rendercache.srt
    local right, up = math3d.index(srt, 1), math3d.index(srt, 2)
    local pos = math3d.index(srt, 4)

    local nq = math3d.mul(
        math3d.quaternion{axis=right, r=dx},
        math3d.quaternion{axis=up, r=dy})

    pos = math3d.transform(nq, pos, 1)

    local newdir = math3d.normalize(math3d.sub(viewpt, pos))
    iobj_motion.set_direction(eid, newdir)

    if distance then
        iobj_motion.set_position(eid, math3d.muladd(newdir, distance, pos))
    else
        iobj_motion.set_position(eid, pos)
    end
end

function iobj_motion.rotate(eid, rotateX, rotateY)
    if rotateX or rotateY then
        local rc = world[eid]._rendercache
        local srt = rc.srt
        srt.id = add_rotation(srt, rotateX, rotateY)
        if rc.updir then
            local viewdir, eyepos = srt[3], srt[4]
            srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, rc.updir))
        end

        world:pub{"component_changed", "transform", eid}
    end
end

function iobj_motion.rotate_around_point(eid, targetpt, distance, rotateX, rotateY, threshold)
    if rotateX or rotateY then
        local rc = world[eid]._rendercache
        local srt = rc.srt
        local newsrt = math3d.set_index(srt, 4, targetpt)
        newsrt = add_rotation(newsrt, rotateX, rotateY, threshold)
        local dir = math3d.index(newsrt, 3)
        local eyepos = math3d.muladd(distance, math3d.inverse(dir), targetpt)
        srt.id = math3d.set_index(newsrt, 4, eyepos)
        if rc.updir then
            local viewdir, eyepos = srt[3], srt[4]
            srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, rc.updir))
        end

        world:pub{"component_changed", "transform", eid}
    end
end

local function main_queue_viewport_size()
    local mq = world:singleton_entity "main_queue"
    local vp_rt = mq.render_target.view_rect
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
    if not eid then
        return math3d.matrix()
    end
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