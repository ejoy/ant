local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local mu     = import_package "ant.math".util
local mc     = import_package "ant.math".constant

local iobj_motion = ecs.interface "obj_motion"
local icamera = world:interface "ant.camera|camera"

local function find_entity(eid)
    if type(eid) == "table" then
        return eid
    end
    for v in w:select "eid:in" do
        if v.eid == eid then
            return v
        end
    end
    return eid
end

local function get_scene(e)
    if type(e) == "table" then
        w:sync("scene:in", e)
        return e.scene
    end
    return world[e]._rendercache
end

local function get_srt(e)
    return get_scene(e).srt
end

local function set_changed(e)
    world:pub {"scene_changed", e}
end

function iobj_motion.get_position(eid)
    local e = find_entity(eid)
    return math3d.index(get_srt(e), 4)
end

function iobj_motion.set_position(eid, pos)
    local e = find_entity(eid)
    local srt = get_srt(e)
    srt[4] = pos
    set_changed(e)
end

function iobj_motion.get_direction(eid)
    local e = find_entity(eid)
    return math3d.index(get_srt(e), 3)
end

function iobj_motion.set_direction(eid, dir)
    local e = find_entity(eid)
    local rc = get_scene(e)
    local srt = rc.srt
    if rc.updir then
        srt.id = math3d.inverse(math3d.lookto(math3d.index(srt, 4), dir, rc.updir))
    else
        srt.r = math3d.torotation(dir)
    end
    set_changed(e)
end

function iobj_motion.set_srt(eid, srt)
    local e = find_entity(eid)
    get_srt(e).m = srt
    set_changed(e)
end

function iobj_motion.set_view(eid, pos, dir, updir)
    local e = find_entity(eid)
    local rc = get_scene(e)
    local srt = rc.srt
    if rc.updir then
        srt.id = math3d.inverse(math3d.lookto(pos, dir, updir or rc.updir))
    else
        local s = math3d.matrix_scale(srt)
        srt.id = math3d.matrix{s=s, r=math3d.torotation(dir), t=pos}
    end
    set_changed(e)
end

function iobj_motion.set_scale(eid, scale)
    local e = find_entity(eid)
    local srt = get_srt(e)
    if type(scale) == "number" then
        srt.s = {scale, scale, scale}
    else
        srt.s = scale
    end
    set_changed(e)
end

function iobj_motion.get_scale(eid)
    local e = find_entity(eid)
    return math3d.matrix_scale(get_srt(e))
end

function iobj_motion.set_rotation(eid, rot)
    local e = find_entity(eid)
    local rc = get_scene(e)
    local srt = rc.srt
    if rc.updir then
        local viewdir
        if type(rot) == "table" then
            viewdir = math3d.todirection(math3d.quaternion{math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])})
        else
            viewdir = math3d.todirection(rot)
        end
        srt.id = math3d.inverse(math3d.lookto(math3d.index(srt, 4), viewdir, rc.updir))
    else
        srt.r = rot
    end
    set_changed(e)
end

function iobj_motion.get_rotation(eid)
    local e = find_entity(eid)
    return get_srt(e).r
end

function iobj_motion.worldmat(eid)
    local e = find_entity(eid)
    local scene = get_scene(e)
    return scene._worldmat
end

function iobj_motion.lookto(eid, eyepos, viewdir, updir)
    local e = find_entity(eid)
    local rc = get_scene(e)
    if updir then
        if rc.updir == nil then
            rc.updir = math3d.ref(math3d.vector(0, 1, 0, 0))
        end
        rc.updir.v = updir
    end
    rc.srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, updir))
    set_changed(e)
end

function iobj_motion.move_delta(eid, delta_vec)
    local e = find_entity(eid)
    local srt = get_srt(e)
    local pos = math3d.add(math3d.index(srt, 4), delta_vec)
    iobj_motion.set_position(eid, pos)
end

function iobj_motion.move_along_axis(eid, axis, delta)
    local p = iobj_motion.get_position(eid)
    iobj_motion.set_position(eid, math3d.muladd(axis, delta, p))
end

function iobj_motion.move(eid, v)
    local e = find_entity(eid)
    local srt = get_srt(e)
    local p = math3d.index(srt, 4)
    for i=1, 3 do
        p = math3d.muladd(v[i], math3d.index(srt, i), p)
    end
    iobj_motion.set_position(eid, p)
end

function iobj_motion.move_forward(eid, v)
    local e = find_entity(eid)
    local srt = get_srt(e)
    local f = math3d.normalize(math3d.index(srt, 3))
    iobj_motion.move_along_axis(eid, f, v)
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
        local e = find_entity(eid)
        local rc = get_scene(e)
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
        set_changed(e)
    end
end

function iobj_motion.rotate_around_point2(eid, viewpt, dx, dy, distance)
    local e = find_entity(eid)
    local srt = get_scene(e).srt
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
        local e = find_entity(eid)
        local rc = get_scene(e)
        local srt = rc.srt
        srt.id = add_rotation(srt, rotateX, rotateY)
        if rc.updir then
            local viewdir, eyepos = srt[3], srt[4]
            srt.id = math3d.inverse(math3d.lookto(eyepos, viewdir, rc.updir))
        end
        set_changed(e)
    end
end

function iobj_motion.rotate_around_point(eid, targetpt, distance, rotateX, rotateY, threshold)
    if rotateX or rotateY then
        local e = find_entity(eid)
        local rc = get_scene(e)
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
        set_changed(e)
    end
end

local function main_queue_viewport_size()
    local e = w:singleton("main_queue", "render_target:in")
    return e.render_target.view_rect
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

function iobj_motion.screen_to_ndc(eid, pt2d, vp_size)
    vp_size = vp_size or main_queue_viewport_size()
    local ndc = mu.pt2D_to_NDC(pt2d, vp_size)
    return {ndc[1], ndc[2], pt2d[3]}
end

function iobj_motion.calc_viewmat(eid)
    local e = find_entity(eid)
    local rc = get_scene(e)
    return math3d.lookto(math3d.index(rc.srt, 4), math3d.index(rc.srt, 3), rc.updir)
end

for n, f in pairs(iobj_motion) do
    ecs.method[n] = f
end
