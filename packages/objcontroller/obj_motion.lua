local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local renderpkg = import_package "ant.render"
local cu = renderpkg.components

local iobj = {}; iobj.__index = iobj
function iobj.create(obj_accessor)
    return setmetatable(obj_accessor, iobj)
end

function iobj:target(eid, locktype, lock_eid, offset)
    local ce = world[eid]
    if ce.lock_target == nil then
        error(string.format("%d already has 'lock_target'", eid))
    end

    if ce == nil then
        error(string.format("invalid camera:%d", eid))
    end

    if world[lock_eid].transform == nil then
        error(string.format("camera lock target entity must have transform component"));
    end

    ce["lock_target"] = world:create_component("lock_target", {
        type    = locktype,
        target  = lock_eid,
        offset  = offset
    })
end

function iobj:move(eid, delta_vec)
    local e = world[eid]
    local p = self:get_position(e)
    self:set_position(e, math3d.add(p, delta_vec))
end

function iobj:move_along_axis(eid, axis, delta)
    local e = world[eid]
    local p = self:get_position(e)
    self:set_position(e, math3d.muladd(axis, delta, p))
end

function iobj:move_along(eid, delta_vec)
    local e = world[eid]
    local dir = self:get_direction(e)
    local pos = self:get_position(e)

    local right, up = math3d.base_axes(dir)
    local x = math3d.muladd(right, delta_vec[1], pos)
    local y = math3d.muladd(up, delta_vec[2], x)
    self:set_position(e, math3d.muladd(dir, delta_vec[3], y))
end

function iobj:move_toward(eid, where, delta)
    local e = world[eid]
    local viewdir = self:get_direction(e)
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

    local p = self:get_position(e)
    self:set_position(e, math3d.muladd(axisdir, delta, p))
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

    local q = math3d.mul(qy, qx)
    return math3d.transform(q, mc.ZAXIS, 0)
end

function iobj:rotate(eid, rotateX, rotateY)
    if rotateX or rotateY then
        local e = world[eid]
        self:set_direction(e, rotate_vec(self:get_direction(e), rotateX, rotateY))
    end
end

function iobj:rotate_around_point(eid, targetpt, distance, dx, dy, threshold_around_x_axis)
    local e = world[eid]
    threshold_around_x_axis = threshold_around_x_axis or 0.002

    local dir = self:get_direction(e)
    self:set_direction(e, math3d.normalize(rotate_vec(dir, dx, dy, threshold_around_x_axis)))
    self:set_position(e, math3d.sub(targetpt, math3d.mul(dir, distance)))

end

local iobj_interfaces = {}
for k in pairs(iobj) do
    iobj_interfaces[#iobj_interfaces+1] = k
end

local function main_queue_viewport_size()
    local mq = world:singleton_entity "main_queue"
    local vp_rt = mq.render_target.viewport.rect
    return {w=vp_rt.w, h=vp_rt.h}
end

function iobj:focus_point(eid, pt)
    local e = world[eid]
	self:set_direction(e, math3d.normalize(pt, self:get_position(e)))
end

function iobj:focus_obj(eid, foucseid)
	local fe = world[foucseid]
	local bounding = cu.entity_bounding(fe)
    if bounding then
        local e = world[eid]
        local aabb = bounding.aabb
        local center, extents = math3d.aabb_center_extents(aabb)
        local radius = math3d.length(extents) * 0.5
        
        local dir = math3d.normalize(math3d.sub(center, self:get_position(e)))
        self:set_direction(e, dir)
        self:set_position(e, math3d.sub(center, math3d.mul(dir, radius * 3.5)))
    else
        iobj:focus_point(eid, fe.transform.srt.t)
	end
end

local iobj_motion = ecs.interface "obj_motion"

local function init_motion_interface(motion, accessor)
    local base_interface = iobj.create(accessor)

    for _, v in ipairs{accessor, iobj} do
        for k in pairs(v) do
            if k ~= '__index' then
                local f = base_interface[k]
                motion[k] = function (...)
                    return f(base_interface, ...)
                end
            end
        end
    end
end

init_motion_interface(iobj_motion, {
    get_position = function (_, e)
        return math3d.index(e.transform.srt, 3)
    end,
    set_position = function (_, e, pos)
        e.transform.srt.t = pos
    end,

    get_direction = function (_, e)
        return math3d.forward_dir(e.transform.srt)
    end,
    set_direction = function (_, e, dir)
        e.transform.srt.r = math3d.torotation(dir)
    end
})

local icameramotion = ecs.interface "camera_motion"
init_motion_interface(icameramotion, {
    get_position = function (_, e)
        return e.camera.eyepos
    end,
    set_position = function (_, e, pos)
        e.camera.eyepos.v = pos
    end,

    get_direction = function (_, e)
        return e.camera.viewdir
    end,

    set_direction = function (_, e, dir)
        e.camera.viewdir.v = dir
    end
})

function icameramotion.ray(eid, pt2d, vp_size)
    local e = world[eid]
    local camera = e.camera
    
    vp_size = vp_size or main_queue_viewport_size()

    local ndc_near, ndc_far = mu.NDC_near_far_pt(mu.pt2D_to_NDC(pt2d, vp_size))

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