local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mu     = import_package "ant.math".util
local mc     = import_package "ant.math".constant

local iobj_motion = ecs.interface "iobj_motion"

local function set_changed(e)
    --TODO: opt performance
    local v = world:entity(e.eid)
    v.scene_needchange = true
end

local function set_s(srt, v)
    math3d.unmark(srt.s)
    srt.s = math3d.mark(math3d.vector(v))
end

local function set_r(srt, v)
    math3d.unmark(srt.r)
    srt.r = math3d.mark(math3d.quaternion(v))
end

local function set_t(srt, v)
    math3d.unmark(srt.t)
    srt.t = math3d.mark(math3d.vector(v))
end

local function set_mat(srt, v)
    math3d.unmark(srt.mat)
    srt.mat = math3d.mark(v)
end

local function set_srt(srt, s, r, t)
    set_s(srt, s)
    set_r(srt, r)
    set_t(srt, t)
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
    return e.scene and e.scene.t
end

function iobj_motion.set_position(e, pos)
    local srt = e.scene
    if not srt then
        return
    end
    set_t(srt, pos)
    set_changed(e)
end

function iobj_motion.get_direction(e)
    return e.scene and math3d.todirection(e.scene.r)
end


function iobj_motion.set_direction(e, dir)
    local scene = e.scene
    if not scene then
        return
    end
    if scene.updir ~= mc.NULL then
        local _srt = math3d.inverse(math3d.lookto(scene.t, dir, scene.updir))
        local s, r, t = math3d.srt(_srt)
        set_srt(scene, s, r, t)
    else
        set_r(scene, math3d.torotation(dir))
    end
    set_changed(e)
end

function iobj_motion.set_srt(e, s, r, t)
    if not e.scene then
        return
    end
    set_srt(e.scene, s, r, t)
    set_changed(e)
end

function iobj_motion.set_srt_matrix(e, mat)
    if not e.scene then
        return
    end
    reset_srt(e.scene)
    set_mat(e.scene, mat)
    set_changed(e)
end

function iobj_motion.set_srt_offset_matrix(e, mat)
    if not e.scene then
        return
    end
    set_mat(e.scene, mat)
    set_changed(e)
end

function iobj_motion.set_view(e, pos, dir, updir)
    local scene = e.scene
    if not scene then
        return
    end
    if updir then
        math3d.unmark(scene.updir)
        scene.updir = math3d.mark(updir)
        local _srt = math3d.inverse(math3d.lookto(pos, dir, scene.updir))
        local s, r, t = math3d.srt(_srt)
        set_srt(scene, s, r, t)
    else
        set_srt(scene, scene.s, math3d.torotation(dir), pos)
    end
    set_changed(e)
end

function iobj_motion.set_scale(e, scale)
    local srt = e.scene
    if not srt then
        return
    end
    if type(scale) == "number" then
        set_s(srt, {scale, scale, scale})
    else
        set_s(srt, scale)
    end
    set_changed(e)
end

function iobj_motion.get_scale(e)
    return e.scene and e.scene.s
end

function iobj_motion.set_rotation(e, rot)
    local scene = e.scene
    if not scene then
        return
    end
    local srt = scene
    if scene.updir ~= mc.NULL then
        local viewdir
        if type(rot) == "table" then
            viewdir = math3d.todirection(math3d.quaternion{math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])})
        else
            viewdir = math3d.todirection(rot)
        end

        local _srt = math3d.inverse(math3d.lookto(srt.t, viewdir, scene.updir))
        local s, r, t = math3d.srt(_srt)
        set_srt(srt, s, r, t)
    else
        set_r(srt, rot)
    end
    set_changed(e)
end

function iobj_motion.get_rotation(e)
    return e.scene and e.scene.r
end

function iobj_motion.worldmat(e)
    local scene = e.scene
    return scene and scene.worldmat
end

function iobj_motion.lookto(e, eyepos, viewdir, updir)
    local scene = e.scene
    if not scene then
        return
    end
    if updir then
        math3d.unmark(scene.updir)
        scene.updir = math3d.mark(updir)
    end
    local srt = math3d.inverse(math3d.lookto(eyepos, viewdir, updir))
    local s, r, t = math3d.srt(srt)
    set_srt(e.scene, s, r, t)
    set_changed(e)
end

function iobj_motion.move_delta(e, delta_vec)
    local srt = e.scene
    if not srt then
        return
    end
    local pos = math3d.add(srt.t, delta_vec)
    iobj_motion.set_position(e, pos)
end

function iobj_motion.move_along_axis(e, axis, delta)
    if not e.scene then
        return
    end
    local p = iobj_motion.get_position(e)
    iobj_motion.set_position(e, math3d.muladd(axis, delta, p))
end

function iobj_motion.move(e, v)
    local srt = e.scene
    if not srt then
        return
    end
    local p = math3d.vector(srt.t)
    local srtmat = math3d.matrix(srt)
    for i=1, 3 do
        p = math3d.muladd(v[i], math3d.index(srtmat, i), p)
    end
    iobj_motion.set_position(e, p)
end

function iobj_motion.move_right(e, v)
    local srt = e.scene
    if not srt then
        return
    end
    local right = math3d.transform(srt.r, mc.XAXIS, 0)
    iobj_motion.move_along_axis(e, right, v)
end

function iobj_motion.move_up(e, v)
    local srt = e.scene
    if not srt then
        return
    end
    local up = math3d.transform(srt.r, mc.YAXIS, 0)
    iobj_motion.move_along_axis(e, up, v)
end

function iobj_motion.move_forward(e, v)
    local srt = e.scene
    if not srt then
        return
    end
    local f = math3d.todirection(srt.r)
    iobj_motion.move_along_axis(e, f, v)
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
    local xaxis, yaxis, zaxis = math3d.index(srt, 1, 2, 3)

    local nq = math3d.mul(
        math3d.quaternion{axis=xaxis, r=rx},
        math3d.quaternion{axis=yaxis, r=ry})
    
    return math3d.transform(nq, zaxis, 0)
end

function iobj_motion.rotate_forward_vector(e, rotateX, rotateY)
    if not e.scene then
        return
    end
    if rotateX or rotateY then
        local scene = e.scene
        local srt = scene
        local srtmat = math3d.matrix(srt)
        local viewdir = math3d.normalize(rotate_forword_vector(srtmat, rotateX, rotateY))
        
        if scene.updir ~= mc.NULL then
            srtmat = math3d.inverse(math3d.lookto(srt.t, viewdir, scene.updir))
        else
            local xaxis, yaxis
            if math3d.isequal(mc.YAXIS, viewdir) then
                xaxis = mc.XAXIS
                yaxis = mc.NZAXIS
            elseif math3d.isequal(mc.NYAXIS, viewdir) then
                xaxis = mc.XAXIS
                yaxis = mc.ZAXIS
            else
                xaxis = math3d.normalize(math3d.cross(mc.YAXIS, viewdir))
                yaxis = math3d.cross(viewdir, xaxis)
            end
            srtmat = math3d.set_columns(mc.IDENTITY_MAT, xaxis, yaxis, viewdir, srt.t)
        end

        local s, r, t = math3d.srt(srtmat)
        set_srt(srt, s, r, t)
        set_changed(e)
    end
end

function iobj_motion.rotate_around_point2(e, viewpt, dx, dy, distance)
    if not e.scene then
        return
    end
    local srt = e.scene
    local srtmat = math3d.matrix(srt)
    local right, up, pos = math3d.index(srtmat, 1, 2, 4)

    local nq = math3d.mul(
        math3d.quaternion{axis=right, r=dx},
        math3d.quaternion{axis=up, r=dy})

    pos = math3d.transform(nq, pos, 1)

    local newdir = math3d.normalize(math3d.sub(viewpt, pos))
    iobj_motion.set_direction(e, newdir)

    if distance then
        iobj_motion.set_position(e, math3d.muladd(newdir, distance, pos))
    else
        iobj_motion.set_position(e, pos)
    end
end

function iobj_motion.rotate(e, rotateX, rotateY)
    if not e.scene then
        return
    end
    if rotateX or rotateY then
        local scene = e.scene
        local srt = math3d.matrix(scene)
        srt = add_rotation(srt, rotateX, rotateY)
        if scene.updir ~= mc.NULL then
            local viewdir, eyepos = math3d.index(srt, 3, 4)
            srt = math3d.inverse(math3d.lookto(eyepos, viewdir, scene.updir))
        end

        local s, r, t = math3d.srt(srt)
        set_srt(scene, s, r, t)
        set_changed(e)
    end
end

function iobj_motion.rotate_around_point(e, targetpt, distance, rotateX, rotateY, threshold)
    if not e.scene then
        return
    end
    if rotateX or rotateY then
        local rc = e.scene
        local srt = rc
        local newsrt = math3d.matrix(srt)
        newsrt = math3d.set_index(newsrt, 4, targetpt)
        newsrt = add_rotation(newsrt, rotateX, rotateY, threshold)
        local dir = math3d.index(newsrt, 3)
        local eyepos = math3d.muladd(distance, math3d.inverse(dir), targetpt)
        newsrt = math3d.set_index(newsrt, 4, eyepos)
        if rc.updir ~= mc.NULL then
            local viewdir, eyepos = srt[3], srt[4]
            newsrt = math3d.inverse(math3d.lookto(eyepos, viewdir, rc.updir))
        end

        local s, r, t = math3d.srt(newsrt)
        set_srt(srt, s, r, t)
        set_changed(e)
    end
end

local function main_queue_viewport_size()
    local e = w:singleton("main_queue", "render_target:in")
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

for n, f in pairs(iobj_motion) do
    ecs.method[n] = f
end
