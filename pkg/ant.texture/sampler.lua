local math3d = require "math3d"

local function DEF_IMPL() assert(false, "need implement") end

local ADDRESS_FINDER<const> = {
    CLAMP = function (v, minv, maxv)
        return math.max(minv, math.min(v, maxv))
    end,
    MIRROR  = DEF_IMPL,
    BORDER  = DEF_IMPL,
    WRAP    = DEF_IMPL,
}

local FILTER_FINDER<const> = {
    POINT = DEF_IMPL,
    LINEAR = function(x, y, nx, ny, px, py, load_op)
        local lt, rt, lb, rb = load_op(x, y), load_op(nx, y), load_op(x, ny), load_op(nx, ny)

        local tv = math3d.lerp(lt, rt, px)
        local bv = math3d.lerp(lb, rb, px)
        return math3d.lerp(tv, bv, py)
    end,
    ANISOTROPIC = DEF_IMPL,
}

local function find_filter_mode(ddx, ddy)
    --TODO: dependand on ddx/ddy, to use find
    return "mag"
end

local DEFAULT_SAMPLER<const> = {
    address = {u = ADDRESS_FINDER.CLAMP, v = ADDRESS_FINDER.CLAMP},
    filter_modes = {
        mip = FILTER_FINDER.LINEAR,
        min = FILTER_FINDER.LINEAR,
        mag = FILTER_FINDER.LINEAR,
    },
    filter = function (self, ...)
        local m = find_filter_mode(self.ddx, self.ddy)
        return self.filter_modes[m](...)
    end,
}

local function create_sampler(s)
    --TODO: need to check sampler flags to create a sampler obj
    return DEFAULT_SAMPLER
end


return {
    DEFAULT = DEFAULT_SAMPLER,
    create = create_sampler,
}