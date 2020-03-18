local f = {}; f.__index = f
local math3d = require "math3d"

function f.new(mat)
    return setmetatable(
        {
            planes = math3d.frustum_planes(mat),
            points = math3d.frustum_points(mat),
        }, f)
end

return f