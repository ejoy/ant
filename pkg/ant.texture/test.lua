local math3d    = require "math3d"
local tu        = require "texture"

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