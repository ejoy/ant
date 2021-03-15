local math3d = require "math3d"
local constant = require "constant"

local ctrunkid = {}
setmetatable(ctrunkid, {
    __call = function (_, trunkid, qs)
        return setmetatable({
            trunkid = trunkid,
            qs = qs,
        }, {__index=ctrunkid})
    end
})

--trunid:
--  tx: [0, 13], ty:[14, 27], f: [28, 31]
function ctrunkid.trunkid_face(trunkid)
    return trunkid >> 28
end

function ctrunkid.trunkid_index(trunkid)
    return (0x00003fff & trunkid), (0x0fffffff & trunkid) >> 14
end

function ctrunkid.pack_trunkid(face, tx, ty)
    return (face << 28|ty << 14 |tx)
end

function ctrunkid:face()
    return ctrunkid.trunkid_face(self.trunkid)
end

function ctrunkid:trunk_index_coord()
    return ctrunkid.trunkid_index(self.trunkid)
end

function ctrunkid:unpack()
    local t = self.trunkid
    return ctrunkid.trunkid_face(t), ctrunkid.trunkid_index(t)
end

--[[
    r:      raidus
    theta:  [0, pi/2]
    phi:    [0, 2*pi]
    x:      r*sin(theta)*cos(phi)
    y:      r*sin(theta)*sin(phi)
    z:      r*cos(theta)

    r:      sqrt(dot(p))
    theta:  arccos(z/r)
    phi:    arccos(x/(r*sin(theta)))
]]
function ctrunkid:to_sphereical_coord(xyzcoord)
    local nc = math3d.tovalue(math3d.mul(1/self.qs.radius, math3d.vector(xyzcoord)))
    local theta = math.acos(nc[3])
    local sintheta = math.sin(theta)
    local phi = math.acos(nc[1]/sintheta)
    return theta, phi
end

function ctrunkid:to_xyz(theta, phi)
    local sintheta, costheta = math.sin(theta), math.cos(theta)
    local sinphi, cosphi    = math.sin(phi), math.cos(phi)
    return math3d.mul(self.ps.raidus, math3d.vector(sintheta*cosphi, sintheta*sinphi, costheta))
end

function ctrunkid.quad_corners(facepoints, inv_num, ix, iy)
    local h = math3d.sub(facepoints[2], facepoints[1])
    local v = math3d.sub(facepoints[4], facepoints[1])
    local dh, dv = math3d.mul(h, inv_num), math3d.mul(v, inv_num)
    local p = math3d.muladd(dh, ix, facepoints[1])
    p = math3d.muladd(dv, iy, p)

    local p1 = math3d.add(p, dh)
    return {
        p,                                 p1,
        math3d.add(dv, p1), math3d.add(p, dv),
    }
end

function ctrunkid.quad_delta(corners, inv_num)
    local h = math3d.sub(corners[2], corners[1])
    local v = math3d.sub(corners[4], corners[1])

    return  math3d.mul(h, inv_num),
            math3d.mul(v, inv_num),
            corners[1]
end

function ctrunkid:tile_delta(inv_num)
    return ctrunkid.quad_delta(self:proj_corners_3d(), inv_num)
end

function ctrunkid:proj_corners_3d()
    local tx, ty = self:trunk_index_coord()
    local qs = self.qs
    local face = self:face()
    local fv = qs.inscribed_cube[face+1]
    return ctrunkid.quad_corners(fv, qs.inv_num_trunk, tx, ty)
end

local function surface_point(radius, v)
    return math3d.mul(radius, math3d.normalize(v))
end

ctrunkid.surface_point = surface_point

function ctrunkid.quad_position(hd, vd, sx, sy, basept)
    local hp = math3d.muladd(hd, sx, basept)
    return math3d.muladd(vd, sy, hp)
end

function ctrunkid.iter_point(n, d, basept)
    local idx=0
    return function ()
        if idx <= n then
            local p = math3d.muladd(d, idx, basept)
            idx = idx + 1
            return p
        end
    end
end

function ctrunkid:corners_3d()
    local projcorners = self:proj_corners_3d()
    local qs = self.qs
    local radius = qs.radius
    
    local s = {}
    for i, c in ipairs(projcorners) do
        s[i] = surface_point(radius, c)
    end
    return s
end

function ctrunkid.tile_vertices(trunkid, qs)
    local radius    = qs.radius
    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(constant.inv_tile_pre_trunk_line)

    local vertices = {}
    local aabb = math3d.aabb()
    for vp in ctrunkid.iter_point(constant.tile_pre_trunk_line, vd, basept) do
        for p in ctrunkid.iter_point(constant.tile_pre_trunk_line, hd, vp) do
            local sp = ctrunkid.surface_point(radius, p)
            aabb = math3d.aabb_append(aabb, sp)
            local v = math3d.tovalue(sp)
            vertices[#vertices+1] = v[1]
            vertices[#vertices+1] = v[2]
            vertices[#vertices+1] = v[3]
        end
    end
    return vertices, aabb
end


return ctrunkid