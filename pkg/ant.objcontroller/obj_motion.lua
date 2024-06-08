local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mu     = import_package "ant.math".util
local mc     = import_package "ant.math".constant

local iobj_motion = {}

local function set_changed(e)
    w:extend(e, "scene:out scene_needchange?out")
    e.scene_needchange = true
end

local function set_s(srt, v)
    math3d.unmark(srt.s)
    srt.s = math3d.marked_vector(v)
end

local function set_r(srt, v)
    math3d.unmark(srt.r)
    srt.r = math3d.marked_quat(v)
end

local function set_t(srt, v)
    math3d.unmark(srt.t)
    srt.t = math3d.marked_vector(v)
end

local function set_mat(srt, v)
    math3d.unmark(srt.mat)
    srt.mat = math3d.mark(v)
end

local function set_srt(srt, s, r, t)
    if s then set_s(srt, s) end
	if r then set_r(srt, r) end
    if t then set_t(srt, t) end
end

local function reset_srt(srt)
    math3d.unmark(srt.s)
    math3d.unmark(srt.r)
    math3d.unmark(srt.t)
    srt.s = mc.ONE
    srt.r = mc.IDENTITY_QUAT
    srt.t = mc.ZERO_PT
end

function iobj_motion.get_position(e)
    w:extend(e, "scene:in")
    return e.scene.t
end

function iobj_motion.set_position(e, pos)
    w:extend(e, "scene:update")
    set_t(e.scene, pos)
    set_changed(e)
end

local function refine_rotation_from_viewdir(scene, viewdir)
    if scene.updir ~= mc.NULL then
        local m = math3d.transpose(math3d.lookto(scene.t, viewdir, scene.updir))
        return math3d.quaternion(m)
    end
    return math3d.torotation(viewdir)
end

function iobj_motion.get_direction(e)
    w:extend(e, "scene:in")
    return math3d.todirection(e.scene.r)
end

function iobj_motion.set_direction(e, viewdir)
    w:extend(e, "scene:in")
    local scene = e.scene
    set_r(scene, refine_rotation_from_viewdir(scene, viewdir))
    set_changed(e)
end

local function refine_rotation(scene, r)
    if scene.updir ~= mc.NULL then
        local viewdir = math3d.todirection(r)
        local m = math3d.transpose(math3d.lookto(scene.t, viewdir, scene.updir))
        return math3d.quaternion(m)
    end
    return r
end

function iobj_motion.set_rotation(e, rot)
    w:extend(e, "scene:in")
    local scene = e.scene
    set_r(scene, refine_rotation(scene, rot))
    set_changed(e)
end

function iobj_motion.get_rotation(e)
    w:extend(e, "scene:in")
    return e.scene.r
end

function iobj_motion.set_srt(e, s, r, t)
    w:extend(e, "scene:in")
    set_srt(e.scene, s, r, t)
    set_changed(e)
end

function iobj_motion.set_srt_matrix(e, mat)
    w:extend(e, "scene:in")
    local scene = e.scene
    reset_srt(scene)
    set_mat(scene, mat)
    set_changed(e)
end

function iobj_motion.set_srt_offset_matrix(e, mat)
    w:extend(e, "scene:in")
    set_mat(e.scene, mat)
    set_changed(e)
end

function iobj_motion.set_view(e, pos, dir, updir)
    w:extend(e, "scene:in")
    local scene = e.scene
    if updir then
        math3d.unmark(scene.updir)
        scene.updir = math3d.mark(updir)
    end

    local r = refine_rotation_from_viewdir(scene, dir)
    set_srt(scene, nil, r, pos)
    set_changed(e)
end

function iobj_motion.set_scale(e, scale)
    w:extend(e, "scene:in")
    local srt = e.scene
    if type(scale) == "number" then
        set_s(srt, {scale, scale, scale})
    else
        set_s(srt, scale)
    end
    set_changed(e)
end

function iobj_motion.get_scale(e)
    w:extend(e, "scene:in")
    return e.scene.s
end

function iobj_motion.worldmat(e)
    w:extend(e, "scene:in")
    return e.scene.worldmat
end

iobj_motion.lookto = iobj_motion.set_view

function iobj_motion.move_delta(e, delta_vec)
    w:extend(e, "scene:in")
    local scene = e.scene
    local pos = math3d.add(scene.t, delta_vec)
    iobj_motion.set_position(e, pos)
end

function iobj_motion.move_along_axis(e, axis, delta)
    w:extend(e, "scene:in")
    local p = iobj_motion.get_position(e)
    iobj_motion.set_position(e, math3d.muladd(axis, delta, p))
end

function iobj_motion.move(e, v)
    w:extend(e, "scene:in")
    local srt = e.scene
    local p = srt.t
    local srtmat = math3d.matrix(srt)
    for i=1, 3 do
        p = math3d.muladd(v[i], math3d.index(srtmat, i), p)
    end
    iobj_motion.set_position(e, p)
end

function iobj_motion.move_right(e, v)
    w:extend(e, "scene:in")
    local scene = e.scene
    local right = math3d.transform(scene.r, mc.XAXIS, 0)
    iobj_motion.move_along_axis(e, right, v)
end

function iobj_motion.move_up(e, v)
    w:extend(e, "scene:in")
    local scene = e.scene
    local up = math3d.transform(scene.r, mc.YAXIS, 0)
    iobj_motion.move_along_axis(e, up, v)
end

function iobj_motion.move_forward(e, v)
    w:extend(e, "scene:in")
    local scene = e.scene
    local f = math3d.todirection(scene.r)
    iobj_motion.move_along_axis(e, f, v)
end

local function get_rotator(r, rx, ry)
    local m = math3d.matrix(r)
    local xaxis, yaxis = math3d.index(m, 1, 2)
    return math3d.mul(math3d.mul(
        math3d.quaternion{axis=xaxis, r=rx},
        math3d.quaternion{axis=yaxis, r=ry}
    ), r)
end

function iobj_motion.rotate_forward_vector(e, rotateX, rotateY)
    if rotateX or rotateY then
        w:extend(e, "scene:in")
        local scene = e.scene
        local r = get_rotator(scene.r, rotateX, rotateY)
        set_r(scene, refine_rotation(scene, r))
        set_changed(e)
    end
end

function iobj_motion.rotate_around_point(e, lastru, dx, dy)
    
    local scene = e.scene
    local m = math3d.matrix(scene.r)
    local xaxis, yaxis = math3d.index(m, 1, 2)
    local q = math3d.mul(
        math3d.quaternion{axis=xaxis, r=dx},
        math3d.quaternion{axis=yaxis, r=dy}
    )
    local p=math3d.sub(scene.t, lastru)
    local v = math3d.transform(q, p, 0)
    p = math3d.add(v, lastru)

    set_t(scene, p)
    local nq = math3d.mul(q, scene.r)
    set_r(scene, refine_rotation(scene,nq))
    set_changed(e)
    local distance=math3d.length(v)
    local lookat=math3d.normalize(math3d.todirection(scene.r))
    return distance,lookat,p
end

local function main_queue_viewport_size()
    local e = w:first("main_queue render_target:in")
    return e.render_target.view_rect
end

function iobj_motion.ray(vpmat, pt2d, vp_size)
    vp_size = vp_size or main_queue_viewport_size()

    local ndc_near, ndc_far = mu.NDC_near_far_pt(mu.pt2D_to_NDC(pt2d, vp_size))

    local invviewproj = math3d.inverse(vpmat)
    local pt_near_WS = math3d.transformH(invviewproj, ndc_near, 1)
    local pt_far_WS = math3d.transformH(invviewproj, ndc_far, 1)

    local dir = math3d.normalize(math3d.sub(pt_far_WS, pt_near_WS))
    return {
        origin = pt_near_WS,
        dir = dir,
    }
end

function iobj_motion.screen_to_ndc(pt2d, vp_size)
    vp_size = vp_size or main_queue_viewport_size()
    local ndc = mu.pt2D_to_NDC(pt2d, vp_size)
    return {ndc[1], ndc[2], pt2d[3]}
end

return iobj_motion
