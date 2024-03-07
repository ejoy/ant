local math3d    = require "math3d"
local cube      = require "cube"
local tex2d     = require "2d"

local function fequal(l, r, t)
    t = t or 1e-6
    return math.abs(l - r) < t
end

print "texture2d test"
do
    
end

print "cubemap test"
do
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
    local cmobj = cube.create{w=w, h=h, texelsize=16, data=cm_data}

    print"check uvface2dir and dir2uvface"

    local function print_fuv(f, u, v)
        print("Face: ", cube.face_name(f), "u:", u, "v:", v)
    end
    do
        local face, uu, vv = cube.face_index "-X", 0.25, 0.25
        print_fuv(face, uu, vv)
        local N = cube.uvface2dir(face, uu, vv)
        print("After uvface2dir, the normal is:", math3d.tostring(N))

        local f, u, v = cube.dir2uvface(N)

        print("After 'dir2uvface'")
        print_fuv(f, u, v)
        assert(f == cube.face_index "-X" and fequal(u, uu) and fequal(v, vv), "function 'uvface2dir' and 'dir2uvface' is not pairs")
    end

    print "check load/sample function"
    do
        --cubemap face uv range from[-1, 1]
        --[0.25, 0.25] is the center of the first element in cubemap +X face, it must be green(0.0, 1.0, 0.0, 1.0)
        local f, u, v = cube.face_index "+X", 0.25, 0.25
        local N = cube.uvface2dir(f, u, v)
        print_fuv(f, u, v)
        print("Use normal:", math3d.tostring(N))
        local r = cmobj:sample(N)
        print("Sample result:", math3d.tostring(r))

        assert(math3d.isequal(r, math3d.vector(0.0, 1.0, 0.0)))

        --TODO: if we implement sampler object, we should change this test code, we assume the sample will use double linear interpolation
        local x1, y1 = 1, 1
        local fxy_r1 = cmobj:load_fxy(f, x1, y1)
        print("Use load_fxy:", cube.face_name(f), x1, y1, math3d.tostring(fxy_r1))
        assert(math3d.isequal(fxy_r1, math3d.vector(0.0, 1.0, 0.0)))

        local x2, y2 = 1, 2
        local fxy_r2 = cmobj:load_fxy(f, x2, y2)
        print("Use load_fxy:", cube.face_name(f), x2, y2, math3d.tostring(fxy_r2))
        assert(math3d.isequal(fxy_r2, math3d.vector(1.0, 0.0, 0.0)))
    
        local x3, y3 = 2, 1
        local fxy_r3 = cmobj:load_fxy(f, x3, y3)
        print("Use load_fxy:", cube.face_name(f), x3, y3, math3d.tostring(fxy_r3))

        local x4, y4 = 2, 2
        local fxy_r4 = cmobj:load_fxy(f, x4, y4)
        print("Use load_fxy:", cube.face_name(f), x4, y4, math3d.tostring(fxy_r4))

        do
            local u, v = 0.5, 0.25
            print_fuv(f, u, v)
            N = cube.uvface2dir(f, u, v)
            print("Use normal:", math3d.tostring(N))

            local r = cmobj:sample(N)
            print("Use normal:", math3d.tostring(N), "to sample, result is:", math3d.tostring(r))

            local tr = math3d.lerp(fxy_r1, fxy_r2, 0.5)
            local _ = math3d.isequal(r, tr) or error (("fuv result:%s, is not equal fxy1, fxy2 with 0.5: %s"):format(math3d.tostring(r), math3d.tostring(tr)))
        end
    end
end