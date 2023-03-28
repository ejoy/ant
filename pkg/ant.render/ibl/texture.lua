local tu = {}

local math3d = require "math3d"

local function id2uv(iu, iv, w, h)
    return (iu+0.5)/w, (iv+0.5)/h
end

local function n2s(v)
    return v*2.0 - 1.0
end

local function s2n(v)
    return (v + 1.0) * 0.5
end

local function uvface2dir(face, u, v)
    if face == 1 then
        return math3d.vector( 1.0, v,-u);
    elseif face == 2 then
        return math3d.vector(-1.0, v, u);
    elseif face == 3 then
        return math3d.vector( u, 1.0,-v);
    elseif face == 4 then
        return math3d.vector( u,-1.0, v);
    elseif face == 5 then
        return math3d.vector( u, v, 1.0);
    else
        assert(face == 6)
        return math3d.vector(-u, v,-1.0);
    end
end

local function dir2uvface(v)
    local x, y, z = math3d.index(v, 1, 2, 3)
    local abs = math.abs
    local ax, ay, az = abs(x), abs(y), abs(z)
    
    if ax > ay then
        if ax > az then
            if x > 0 then
                return 1, s2n(-z/ax), s2n(y/ax)   -- +X
            else
                return 2, s2n(z/ax), s2n(y/ax)    -- -X
            end
        end
    else
        if ay > az then
            if y > 0 then
                return 3, s2n(x/ay), s2n(z/ay)    -- +Y
            else
                return 4, s2n(x/ay), s2n(-z/ay)   -- -Y
            end
        end
    end

    if z > 0 then
        return 5, s2n(x/az), s2n(y/az)            -- +Z
    else
        return 6, s2n(x/az), s2n(-y/az)           -- -Z
    end
end

local function DEF_IMPL() assert(false, "need implement") end

local ADDRESS_FINDER<const> = {
    CLAMP = function (v, minv, maxv)
        return math.max(minv, math.min(v, maxv))
    end,
    MIRROR = DEF_IMPL,
    BORDER = DEF_IMPL,
    WRAP = DEF_IMPL,
}

local FILTER_FINDER<const> = {
    POINT = DEF_IMPL,
    LINEAR = function(x, y, nx, ny, px, py, load_op)
        local lt, rt, lb, rb = load_op( x+1,  y+1), load_op(nx+1,  y+1), load_op( x+1, ny+1), load_op(nx+1, ny+1)

        local tv = math3d.lerp(lt, rt, px)
        local bv = math3d.lerp(lb, rb, px)
        return math3d.lerp(tv, bv, py)
    end,
    ANISOTROPIC = DEF_IMPL,
}

local DEFAULT_SAMPLER<const> = {
    address = {u = ADDRESS_FINDER.CLAMP, v = ADDRESS_FINDER.CLAMP},
    filter = {
        mip = FILTER_FINDER.LINEAR,
        min = FILTER_FINDER.LINEAR,
        mag = FILTER_FINDER.LINEAR,
    }
}

local function sample_tex(u, v, w, h, load_op, sampler)
    local iw, ih = 1.0 / w, 1.0 / h

    local function to_xy_index(u, v)
        local a_u, a_v = sampler.address.u(u, 0.0, 1.0), sampler.address.v(v, 0.0, 1.0)
        return a_u * w, a_v * h
    end

    local  fx,  fy = to_xy_index(u, v)
    local nfx, nfy = to_xy_index(u+iw, v+ih)

    -- x, y, nx, ny are base 0
    local  x,  y = math.floor(fx),  math.floor(fy)
    local nx, ny = math.floor(nfx), math.floor(nfy)

    local px, py = fx - x, fy - y

    --TODO: we need to implement ddx/ddy, to find which filter mode is, and select filter after mode is found.
    -- we just keep all sample is linear
    -- FILTER_FINDER.LINEAR is base 1
    return FILTER_FINDER.LINEAR(x+1, y+1, nx+1, ny+1, px, py, load_op)
end

local cm_mt = {
    index_fxy = function(self, face, x, y)
        x, y = math.floor(x), math.floor(y)
        return (face-1)*self.facenum + (y-1)*self.w + x
    end,
    index_fuv = function (self, face, u, v)
        assert(false)
    end,
    normal_fxy = function(self, face, x, y)
        local u, v = id2uv(x, y, self.w, self.h)
        return math3d.normalize(uvface2dir(face, n2s(u), n2s(v)))
    end,

    load = function (self, v3d)
        local face, u, v = dir2uvface(v3d)
        return self:load_fuv(face, u, v)
    end,
    load_fuv = function(self, face, u, v)
        local x, y = math.floor(self.w * u), math.floor(self.h * v)
        return self:load_fxy(self, face, x, y)
    end,
    load_fxy = function (self, face, x, y)
        local idx = self:index_fxy(face, x, y)
        idx = math.min(idx, self.max_index)
        local offset = (idx-1) * self.texelsize+1
        local r, g, b = ('fff'):unpack(self.data, offset)
        return math3d.vector(r, g, b, 0.0)
    end,
    sample = function (self, N)
        local face, u, v = dir2uvface(N)
        return self:sample_fuv(face, u, v)
    end,
    sample_fuv = function (self, face, u, v)
        return sample_tex(u, v, self.w, self.h, function (x, y)
            return self:load_fxy(face, x, y)
        end)
    end,
}

local function create_sampler(s)
    --TODO: need to check sampler flags to create a sampler obj
    return DEFAULT_SAMPLER
end

function tu.create_cubemap(cm, sampler)
    assert(cm.w and cm.h)
    cm.facenum = cm.w * cm.h
    cm.max_index = cm.facenum * 6
    
    cm.sampler = sampler or DEFAULT_SAMPLER
    return setmetatable(cm, {__index=cm_mt})
end

tu.uvface2dir = uvface2dir
tu.dir2uvface = dir2uvface

tu.create_sampler = create_sampler

return tu