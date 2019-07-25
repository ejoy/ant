-- test on $ant_dir
package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"

local mathbaselib = require "math3d.baselib"
local math3d = require "math3d"

local ms = math3d.new()

do
    local bounding = mathbaselib.new_bounding(ms)
    local p1, p2 = ms({0, 1, 0}, {2, 3, 4}, "PP")
    local bounding2 = mathbaselib.new_bounding(ms, p2, p1)
    print("bounding2: ", bounding2)

    local bounding3 = mathbaselib.new_bounding(ms, {0, 0, 0}, {1, 2, 8})
    print("bounding3 : ", bounding3)
    bounding:merge(bounding2, bounding3)
    print("after merged, bouding:", bounding)
end

do
    -- local _, _, vp = 
    -- ms:view_proj({ms({1, 1, -1}, "inT"), {5, 5, -5}}, {type = "mat", n = 0.1, f = 1000, fov = 60, aspect = 806/1024,}, true)
    local frustum = mathbaselib.new_frustum(ms, ms({0.918559, -0.707107, -0.577408, -0.577350,
    0.000000, 1.414214, -0.577408, -0.577350,
    0.918559, 0.707107, 0.577408, 0.577350,
    0.000000, 0.000000, 13.757782, 13.856406}, "P"))

    local _, _, vp = 
    ms:view_proj({viewdir = {0, 0, 1, 0}, eyepos = {0, 0, -5}}, {type = "mat", n = 0.1, f = 1000, fov = 60, aspect = 806/1024,}, true)
    local frustum1 = mathbaselib.new_frustum(ms, vp)
    local b0 = mathbaselib.new_bounding(ms, {-4.257135, 0.025428, -1.035961}, {4.257135, 4.760269, 1.041766})
    print(frustum:intersect(b0))
    print(frustum1:intersect(b0))
    print("frustum:\n", frustum)

    local b1, b2 = 
    mathbaselib.new_bounding(ms, {0, 0, 0}, {1, 1, 1}), 
    mathbaselib.new_bounding(ms, {0, 0, 2}, {2, 2, 4})

    local b3 = mathbaselib.new_bounding(ms, {3000, 0, 0}, {1, 1, 1})

    local boundings = {b1, b2, b3}
    local vis = frustum:intersect_list(boundings)

    for _, v in ipairs(vis)do
        print(v)
    end

end

do
    local b1 = mathbaselib.new_bounding(ms, {0, 1, 0, 0}, {1, 2, 1, 0})
    print(b1)
    
    local planes = {
        left = {0.707107, 0.000000, 0.707107, 5.656854},
        right = {-0.707107, 0.000000, 0.707107, 5.656854},
        top = {0.000000, -0.707107, 0.707107, 5.656854},
        bottom = {0.000000, 0.707107, 0.707107, 5.656854},
        near = {0.000000, 0.000000, 1.000000, 7.000000},
        far = {0.000000, 0.000000, -1.000000, 992.000488},
    }

    for k, p in pairs(planes) do
        print(k, "result : ", mathbaselib.plane_interset(ms, p, b1))
    end
end

do
    local _, _, vp = ms:view_proj({viewdir={0, 0, 1, 0}, eyepos={0, 0, -8, 1}}, {fov=90, aspect=1, n=1, f=1000}, true)
    local frustum = mathbaselib.new_frustum(ms, vp)
    local points = frustum:points()
    for k, p in pairs(points) do
        print(k, p[1], p[2], p[3])
    end
end