local V4_FMT<const> = 'ffff'
local M4_FMT<const> = ('f'):rep(16)

local function append_values(...)
	local c = select("#", ...)
	return ("%s"):rep(c):format(...)
end

local function v4(...) return V4_FMT:pack(...) end
local function m4(...) return M4_FMT:pack(...) end

return {
    ZERO 	= V4_FMT:pack(0, 0, 0, 0),
    ZERO_PT	= V4_FMT:pack(0, 0, 0, 1),
    ONE_PT	= V4_FMT:pack(1, 1, 1, 1),
    IDENTITY_MAT = M4_FMT:pack( 1, 0, 0, 0,
                                0, 1, 0, 0,
                                0, 0, 1, 0,
                                0, 0, 0, 1),
    v4          = v4,
    m4          = m4,
    tv4         = function (v) return v4(v[1], v[2], v[3], v[4])  end,
    tm4         = function (v) return m4(v[1], v[2], v[3], v[4], 
                                         v[5], v[6], v[7], v[8],
                                         v[9], v[10],v[11],v[12],
                                         v[13],v[14],v[15],v[16])  end,
    append_values = append_values,
}