local ecs   = ...
local world = ecs.world
local w     = world.w

local meshpkg = import_package "ant.mesh"
local mathpkg = import_package "ant.math"
local mc, mu  = mathpkg.constant, mathpkg.util
local math3d  = require "math3d"
local bgfx    = require "bgfx"    --we want bgfx.memory_buffer

local IDENTITY_MAT<const> = mc.IDENTITY_MAT

--TODO: maybe we should separate this triagnles's buffer to index base triangles
local MAX_TRIANGLES<const> = 4096
local TRIANGLES = {
    n = 0,
    _buffer = bgfx.memory_buffer(MAX_TRIANGLES * 36),    --one triangle for 36 bytes
    check = function (self, n)
        local triidx = self.n
        if triidx+n >= MAX_TRIANGLES then
            error "Not enough triangles buffer"
        end
    end,
    set_buffer = function(self, buffer, num)
        local triidx = self.n
        local index = triidx*36+1
        self._buffer[index] = buffer
        self.n = triidx + num
    end,
    pointer = function(self)
        return self._buffer.data
    end
}

local irp = {}

local function tribuffer(v0, v1, v2)
    return math3d.serialize(v0):sub(1, 12) .. math3d.serialize(v1):sub(1, 12) .. math3d.serialize(v2):sub(1, 12)
end

function irp.add_triangle(v0, v1, v2)
    TRIANGLES:check(1)
    TRIANGLES:set_buffer(tribuffer(v0, v1, v2), 1)
end

function irp.add_triangles(triangles)
    TRIANGLES:check(#triangles)
    local b = {}
    for _, t in ipairs(triangles) do
        b[#b+1] = tribuffer(t[1], t[2], t[3])
    end

    TRIANGLES:set_buffer(table.concat(b, ""), #triangles)
end

function irp.add_triangles_as_buffer(buffer, num)
    TRIANGLES:check(num)
    TRIANGLES:set_buffer(buffer, num)
end

function irp.from_prefab_mesh(prefab)
end

function irp.from_mesh(meshres, transform)
    transform = transform or IDENTITY_MAT
    local mo = mathpkg.create(meshres, transform)

    for i=1, mo:numv() do
        
    end
end

function irp.clear()
    TRIANGLES.n = 0
end

function irp.find(ptscreen, viewrect, vpmat)
    local ndcnear, ndcfar = mu.NDC_near_far_pt(mu.pt2D_to_NDC(ptscreen, viewrect))
    local invvpmat = math3d.inverse(vpmat)

    local nearWS, farWS = math3d.transform(invvpmat, math3d.vector(ndcnear), 1), math3d.transform(invvpmat, math3d.vector(ndcfar), 1)
    local dir = math3d.sub(farWS, nearWS)
    local t, pt = math3d.triangles_ray(nearWS, dir, TRIANGLES:pointer(), TRIANGLES.n, true)
    if t then
        return pt
    end
end

-- if true then
--     local viewmat = math3d.lookat(math3d.vector(0.0, 0.0, -1.0, 1.0), math3d.vector(0.0, 0.0, 0.0, 1.0), math3d.vector(0.0, 1.0, 0.0, 0.0))
--     local projmat = math3d.projmat{aspect=1.0, fov=45, n=1, f=100}
--     local vp = math3d.mul(projmat, viewmat)

--     irp.add_triangle(math3d.vector(0.0, 0.0, 0.0, 1.0), math3d.vector(0.0, 1.0, 0.0, 1.0), math3d.vector(1.0, 0.0, 0.0, 1.0))
--     local pt = irp.find({64, 64}, {x=0, y=0, w=128, h=128}, vp)
--     assert(math3d.isequal(pt, math3d.vector(0.0, 0.0, 0.0)))
-- end

return irp