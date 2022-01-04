local math3d = require "math3d"

local function pt2line_distance(p0, p1, p)
    local d = math3d.normalize(math3d.sub(p1, p0))
    local x, y = math3d.index(d, 1, 2)
    local n = math3d.vector(y, -x, 0.0)
    return math3d.dot(p0, n) - math3d.dot(p, n)
end

local p0 = math3d.vector(0.0, 1.0, 0.0)
local p1 = math3d.vector(1.0, 0.0, 0.0)

local p = math3d.vector(0.5, 0.5, 0.0)
print(pt2line_distance(p0, p1, p))