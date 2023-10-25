local tu = {}

local math3d = require "math3d"

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
        local lt, rt, lb, rb = load_op(x, y), load_op(nx, y), load_op(x, ny), load_op(nx, ny)

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
    -- FILTER_FINDER.LINEAR is base 1
    return FILTER_FINDER.LINEAR(x+1, y+1, nx+1, ny+1, px, py, load_op)
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

tu.create_sampler = create_sampler

--test
local ENABLE_TEST<const> = false

if ENABLE_TEST then
    local function fequal(l, r, t)
        t = t or 1e-6
        return math.abs(l - r) < t
    end

    local w, h = 2, 2
    local cm_data = ('ffff'):rep(w * h * 6):pack(
        -- +X
        0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, -- Green, Red
        1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, -- Red, Green
        -- -X
        1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0,
        1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0,
        -- +Y
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        -- -Y
        0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
        -- +Z
        0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0,
        0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0,
        -- -Z
        1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0,
        1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0)
    local cmobj = tu.create_cubemap{w=w, h=h, texelsize=16, data=cm_data}

    print"check uvface2dir and dir2uvface"

    local function print_fuv(f, u, v)
        print("Face: ", tu.face_name(f), "u:", u, "v:", v)
    end
    do
        local face, uu, vv = tu.face_index "-X", 0.25, 0.25
        print_fuv(face, uu, vv)
        local N = tu.uvface2dir(face, uu, vv)
        print("After uvface2dir, the normal is:", math3d.tostring(N))

        local f, u, v = tu.dir2uvface(N)

        print("After 'dir2uvface'")
        print_fuv(f, u, v)
        assert(f == tu.face_index "-X" and fequal(u, uu) and fequal(v, vv), "function 'uvface2dir' and 'dir2uvface' is not pairs")
    end

    print "check load/sample function"
    do
        -- 0.25, 0.25 is the first element in cubemap, it must be green(0.0, 1.0, 0.0, 1.0)
        local f, u, v = tu.face_index "+X", 0.25, 0.25
        local N = tu.uvface2dir(f, u, v)
        print_fuv(f, u, v)
        print("Use normal:", math3d.tostring(N))
        local r = cmobj:sample(N)
        print("Sample result:", math3d.tostring(r))

        local rx, ry, rz = math3d.index(r, 1, 2, 3)
        assert(fequal(rx, 0.0) and fequal(ry, 1.0) and fequal(rz, 0.0))

        --TODO: if we implement sampler object, we should change this test code, we assume the sample will use double linear interpolation
        local x1, y1 = 1, 1
        local fxy_r1 = cmobj:load_fxy(f, x1, y1)
        print("Use load_fxy:", tu.face_name(f), x1, y1, math3d.tostring(fxy_r1))
        do
            local r, g, b = math3d.index(fxy_r1, 1, 2, 3)
            assert(fequal(r, 0.0) and fequal(g, 1.0) and fequal(b, 0.0))
        end

        local x2, y2 = 1, 2
        local fxy_r2 = cmobj:load_fxy(f, x2, y2)
        print("Use load_fxy:", tu.face_name(f), x2, y2, math3d.tostring(fxy_r2))
        do
            local r, g, b = math3d.index(fxy_r2, 1, 2, 3)
            assert(fequal(r, 1.0) and fequal(g, 0.0) and fequal(b, 0.0))
        end

        local x3, y3 = 2, 1
        local fxy_r3 = cmobj:load_fxy(f, x3, y3)
        print("Use load_fxy:", tu.face_name(f), x3, y3, math3d.tostring(fxy_r3))

        local x4, y4 = 2, 2
        local fxy_r4 = cmobj:load_fxy(f, x4, y4)
        print("Use load_fxy:", tu.face_name(f), x4, y4, math3d.tostring(fxy_r4))

        do
            local u, v = 0.5, 0.25
            print_fuv(f, u, v)
            N = tu.uvface2dir(f, u, v)
            print("Use normal:", math3d.tostring(N))

            local r = cmobj:sample(N)
            print("Use normal:", math3d.tostring(N), "to sample, result is:", math3d.tostring(r))

            local tr = math3d.lerp(fxy_r1, fxy_r2, 0.5)
            local _ = math3d.isequal(r, tr) or error (("fuv result:%s, is not equal fxy1, fxy2 with 0.5: %s"):format(math3d.tostring(r), math3d.tostring(tr)))
        end

    end

end

return tu