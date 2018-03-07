local math_util = {}
math_util.__index = math_util

function math_util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

function math_util.equal(n0, n1)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return math_util.iszero(n1 - n0)
end

function math_util.iszero(n, threshold)
    threshold = threshold or 0.00001
    return -threshold <= n and n <= threshold
end

return math_util