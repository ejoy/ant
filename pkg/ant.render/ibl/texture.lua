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

local function address_clamp(v, minv, maxv)
    return math.max(minv, math.min(v, maxv))
end

local default_address = address_clamp

local function sample_tex(u, v, w, h, load_op, address_op)
    address_op = address_op or default_address
    local x, y = address_op(math.floor(u * w), 0, w), address_op(math.floor(v * h), 0, h)
    local nx, ny = address_op(x+1, 0, w), address_op(y+1, 0, h)

    local px, py = u-math.floor(u), v-math.floor(v)

    local lt, rt, lb, rb = load_op( x,  y), load_op(nx,  y), load_op( x, ny), load_op(nx, ny)

    local tv = math3d.lerp(lt, rt, px)
    local bv = math3d.lerp(lb, rb, px)
    return math3d.lerp(tv, bv, py)
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
        local offset = (idx-1) * self.texelsize
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

function tu.create_cubemap(cm)
    assert(cm.w and cm.h)
    cm.facenum = cm.w * cm.h
    cm.max_index = cm.facenum * 6
    
    return setmetatable(cm, {__index=cm_mt})
end

tu.uvface2dir = uvface2dir
tu.dir2uvface = dir2uvface

return tu