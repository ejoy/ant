local util = {}
util.__index = util

function util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

function util.equal(n0, n1)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return util.iszero(n1 - n0)
end

function util.iszero(n, threshold)
    threshold = threshold or 0.00001
    return -threshold <= n and n <= threshold
end

function util.srt(ms, s, r, t, is_persistent)
	local t = {type="srt", s=s, r=s, t=t}
	if is_persistent then
		local mat = math3d.ref "matrix"
		ms(mat, t, "=")
		return mat
	end

	return ms(t, "P")
end

function util.srt_address(ms, s, r, t, is_persistent)
	local p = util.srt(ms, s, r, t, is_persistent)
	return ms(p, "m")
end

return util