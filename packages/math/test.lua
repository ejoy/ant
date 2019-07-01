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

