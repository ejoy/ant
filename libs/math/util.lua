local math_util = {}
math_util.__index = math_util

function math_util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

return math_util