local math3d    = require "math3d"
local cube      = require "cube"
local tex2d     = require "2d"

local function fequal(l, r, t)
    t = t or 1e-6
    return math.abs(l - r) < t
end

local function print_tex_info(t)
    print("===texture info===")
    print("\t\twidth: " .. t.w)
    print("\t\theight: " .. t.h)
    print("\t\ttype: " .. (t.type or "NOT SET"))
    print("\t\tdepth: " .. (t.depth or 0))
    print("\t\tlayer: " .. (t.layer or 1))
    print("\t\tformat: " .. t.fmt)
    print("\t\ttexelsize: " .. t.texelsize)
end

print "texture2d test"
do
    local w, h = 4, 4
    --Red Green Blue Black
    --Green Blue Black Red
    --Blue Black Red Green
    --Black Red Green Blue
    local data = ('ffff'):rep(w*h):pack(
        1.0, 0.0, 0.0, 1.0,     0.0, 1.0, 0.0, 0.0,     0.0, 0.0, 1.0, 1.0,     0.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 0.0,     0.0, 0.0, 1.0, 1.0,     0.0, 0.0, 0.0, 1.0,     1.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,     0.0, 0.0, 0.0, 1.0,     1.0, 0.0, 0.0, 1.0,     0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0,     1.0, 0.0, 0.0, 1.0,     0.0, 1.0, 0.0, 0.0,     0.0, 0.0, 1.0, 1.0
    )
    local t = tex2d.create({w=w, h=h, data=data}, {
        address = {
            u = "CLAMP", v = "CLAMP",
        },
        filter_modes = {
            min = "LINEAR",
            max = "LINEAR",
            mip = "POINT",
        },
        filter = "LINEAR",
    })

    assert(t.w > 0 and t.h > 0)
    local txw, txh = 1.0/t.w, 1.0/t.h

    print_tex_info(t)

    print "===texture2d load test"
    do
        print "\tload (1, 1)"
        local p11 = t:load(1, 1)
        print("\t(1, 1)" .. math3d.tostring(p11))
        assert(math3d.isequal(p11, math3d.vector(1.0, 0.0, 0.0)))

        print "\tload (3, 2)"
        local p32 = t:load(3, 2)
        print("\t(3, 2)" .. math3d.tostring(p32))
        assert(math3d.isequal(p32, math3d.vector(0.0, 0.0, 0.0)))
    end

    print "===texture2d sample test"
    do
        
        local function do_test(u, v, test)
            local t1 = t:sample(u, v)
            print(("\t(u, v) = (%f, %f), value:%s"):format(u, v, math3d.tostring(t1)))
            assert(math3d.isequal(t1, test))
        end

        local u, v = txw*0.5, txh*0.5
        do_test(u, v, math3d.vector(1.0, 0.0, 0.0))

        local u1 = u+txw
        do_test(u1, v, math3d.vector(0.0, 1.0, 0.0))

        local u2 = u+txw*0.5
        do_test(u2, v, math3d.lerp(math3d.vector(1.0, 0.0, 0.0), math3d.vector(0.0, 1.0, 0.0), 0.5))
    end
    
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