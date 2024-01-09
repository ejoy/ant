local L = {}

local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

function L.rotation_matrix(viewdirLS)
    -- Orient the shadow map in the direction of the view vector by constructing a
    -- rotation matrix in light space around the z-axis, that aligns the y-axis with the camerainfo's
    -- forward vector (V) -- this gives the wrap direction, vp, for LiSPSM.
	local zLS = math3d.index(viewdirLS, 3)
    if math.abs(zLS) < 0.9995 then    -- dot(mc.ZAXIS, viewdirLS) 
		local x, y      = math3d.index(viewdirLS, 1, 2)
        local vp        = math3d.normalize(math3d.vector(x, y, 0)) -- wrap direction in light-space
        local right     = math3d.cross(vp, mc.ZAXIS)
        local forward   = mc.ZAXIS
		return math3d.transpose(math3d.matrix(right, vp, forward, mc.ZERO_PT))
	end
    return mc.IDENTITY_MAT
end

local function calc_near_far(M, points, idx)
    return mu.aabb_minmax_index(math3d.minmax(points, M), idx)
end

local function warp_frustum(n, f)
    assert(f > n)
    local d = 1 / (f - n)
    local A = (f + n) * d
    local B = -2 * n * f * d
    return math3d.matrix(
            n,   0.0, 0.0, 0.0,
            0.0, A,   0.0, B,
            0.0, 0.0, n,   0.0,
            0.0, 1.0, 0.0, 0.0)
end

-- from filament: ShadowMap::applyLISPSM
function L.warp_matrix(si, li, intersectpointsLS)
    local Lv     = li.Lv
    local Lrp    = math3d.mul(li.Lr, li.Lp)
    local Lrpv   = math3d.mul(Lrp, Lv)

    local nearHit, farHit = si.nearHit, si.farHit

    local LoV    = math3d.dot(li.viewdir, li.lightdir)
    local sinLV  = math.sqrt(math.max(0.0, 1.0 - LoV * LoV))

    -- Virtual near plane -- the default is 1 m, can be changed by the user.
    -- The virtual near plane prevents too much resolution to be wasted in the area near the eye
    -- where shadows might not be visible (e.g. a character standing won't see shadows at her feet).
    local dzn = math.max(0.0, nearHit - si.view_near)
    local dzf = math.max(0.0, si.view_far - farHit)

    -- near/far plane's distance from the eye in view space of the shadow receiver volume.

    -- math3d.inverse(Lv) to transform point in light space to worldspace
    -- camerainfo.cameraviewmat to tranfrom point from worldspace to camera view space
    -- zn/zf, near/far plane distance from camera position
    local zn, zf = calc_near_far(li.Lv2Cv, intersectpointsLS, 3)    -- 3 for z-axis
    assert(zf > zn)
    zn = math.max(zn, si.view_near)
    zf = math.min(zf, si.view_far)

    -- Compute n and f, the near and far planes coordinates of Wp (warp space).
    -- It's found by looking down the Y axis in light space (i.e. -Z axis of Wp,
    -- i.e. the axis orthogonal to the light direction) and taking the min/max
    -- of the shadow receivers' volume.
    -- Note: znear/zfar encoded in Mp has no influence here (b/c we're interested only by the y-axis)
    local n_WS, f_WS = calc_near_far(Lrp, intersectpointsLS, 2) -- 2 for y-axis
    -- const float n = nf[0];              -- near plane coordinate of Mp (light space)
    -- const float f = nf[1];              -- far plane coordinate of Mp (light space)
    local d = math.abs(f_WS - n_WS);    -- Wp's depth-range d (abs necessary because we're dealing with z-coordinates, not distances)

    -- The simplification below is correct only for directional lights
    local z0 = zn                -- for directional lights, z0 = zn
    local z1 = z0 + d * sinLV    -- btw, note that z1 doesn't depend on zf

    -- see nopt1 below for an explanation about this test
    -- sinLV is positive since it comes from a square-root
    local epsilon = 0.02; -- very roughly 1 degree
    if (f_WS > n_WS and sinLV > epsilon and 3.0 * (dzn / (zf - zn)) < 2.0) then
        -- nopt is the optimal near plane distance of Wp (i.e. distance from P).

        -- virtual near and far planes
        local vz0 = math.max(0.0, math.max(math.max(zn, si.zn + dzn), z0))
        local vz1 = math.max(0.0, math.min(math.min(zf, si.zf - dzf), z1))

        -- in the general case, nopt is computed as:
        local nopt0 = (1.0 / sinLV) * (z0 + math.sqrt(vz0 * vz1))

        -- However, if dzn becomes too large, the max error doesn't happen in the depth range,
        -- and the equation below should be used instead. If dzn reaches 2/3 of the depth range
        -- zf-zn, nopt becomes infinite, and we must revert to an ortho projection.
        local nopt1 = dzn / (2.0 - 3.0 * (dzn / (zf - zn)))

        -- We simply use the max of the two expressions
        local nopt = math.max(nopt0, nopt1)

        local cameraposLS = math3d.transformH(Lrpv, li.camerapos);
        local p = math3d.vector(
                -- Another option here is to use lsShadowReceiversCenter.x, which skews less the
                -- x-axis. Doesn't seem to make a big difference in the end.
                math3d.index(cameraposLS, 1),
                n_WS - nopt,
                -- Note: various papers suggest using the shadow receiver's center z coordinate in light
                -- space, i.e. to center "vertically" on the shadow receiver volume.
                -- e.g. (Lrpv * wsShadowReceiversVolume.center()).z
                -- However, simply using 0, guarantees to be centered on the light frustum, which itself
                -- is built from the shadow receiver and/or casters bounds.
                0)

        return math3d.matrix{t=math3d.inverse(p)}, warp_frustum(nopt, nopt + d)
    end
    return mc.IDENTITY_MAT, mc.IDENTITY_MAT
end

return L
