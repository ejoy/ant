local tu = {}

local math3d = require "math3d"
local S = require "sampler"

-- all these helper function's parameters: id2uv, n2s, s2, muvface2dir, are base 0
local function n2s(v)
    return v*2.0 - 1.0
end

local function s2n(v)
    return (v + 1.0) * 0.5
end

local function id2uv(iu, iv, w, h)
    return (iu+0.5)/w, (iv+0.5)/h
end

local function uvface2dir(face, u, v)
    u, v = n2s(u), n2s(v)
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
    local ax, ay, az = math3d.index(math3d.vec_abs(x), 1, 2, 3)

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

local function uv2xy(u, v, w, h, sampler)
    local a_u, a_v = sampler.address.u(u, 0.0, 1.0), sampler.address.v(v, 0.0, 1.0)
    local OX<const>, OY<const> = 0.5, 0.5
    return a_u * w - OX, a_v * h - OY
end



local function sample_tex(u, v, w, h, sampler, load_op)
    local iw, ih = 1.0 / w, 1.0 / h

    local  fx,  fy = uv2xy(   u,    v, w, h, sampler)
    local nfx, nfy = uv2xy(u+iw, v+ih, w, h, sampler)

    -- x, y, nx, ny are base 0
    local  x,  y = math.floor(fx),  math.floor(fy)
    local nx, ny = math.floor(nfx), math.floor(nfy)

    local px, py = fx - x, fy - y

    --TODO: we need to implement ddx/ddy, to find which filter mode is, and select filter after mode is found.
    -- we just keep all sample is linear
    return sampler.fitler(x+1, y+1, nx+1, ny+1, px, py, load_op)
end

--all the method parameters, like: face, x, y, they all base 1
local cm_mt = {
    index_fxy = function(self, face, x, y)
        x, y = math.floor(x), math.floor(y)
        return (face-1)*self.facenum + (y-1)*self.w + x
    end,
    index_fuv = function (self, face, u, v)
        assert(false)
    end,
    normal_fxy = function(self, face, x, y)
        x, y = x-1, y-1
        assert(x >= 0 and y >= 0, "Invalid x or y")
        local u, v = id2uv(x, y, self.w, self.h)
        return math3d.normalize(uvface2dir(face, u, v))
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
        return sample_tex(u, v, self.w, self.h, self.sampler, function (x, y)
            return self:load_fxy(face, x, y)
        end)
    end,
}

function tu.create(cm, sampler)
    assert(cm.w and cm.h)
    cm.facenum = cm.w * cm.h
    cm.max_index = cm.facenum * 6

    cm.sampler = sampler or S.create()
    return setmetatable(cm, {__index=cm_mt})
end

tu.uvface2dir = uvface2dir
tu.dir2uvface = dir2uvface
local FACE_INDEX<const> = {
    ["+X"]=1, ["-X"]=2,
    ["+Y"]=3, ["-Y"]=4,
    ["+Z"]=5, ["-Z"]=6,
}
function tu.face_index(n)
    return FACE_INDEX[n] or error (("Invalid face name:%s"):format(n))
end

function tu.face_name(idx)
    for k, v in pairs(FACE_INDEX) do
        if v == idx then return k end
    end

    error(("Invalid face index:%d"):format(idx))
end

return tu