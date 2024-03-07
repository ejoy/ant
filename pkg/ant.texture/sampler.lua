local math3d = require "math3d"

local function DEF_IMPL() assert(false, "need implement") end

local ADDRESS_MODES<const> = {
    CLAMP = function (v)
        return math.max(0.0, math.min(v, 1.0))
    end,
    MIRROR  = DEF_IMPL,
    BORDER  = DEF_IMPL,
    WRAP    = DEF_IMPL,
}


--TODO: there filters only the two-dimensional case was considered
--box.x/y/nx/ny are base 0
local FILTER_MODES<const> = {
    POINT   = function (so, box)
        return so.load(box.tx+1, box.ty+1)
    end,
    LINEAR = function(so, box)
        local px, py = box.px, box.py

        local tx, ty = box.tx+1, box.ty+1
        local ntx, nty=box.ntx+1, box.nty+1

        local lt, rt = so:load(tx, ty),  so:load(ntx, ty)
        local lb, rb = so:load(tx, nty), so:load(ntx, nty)

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

local function filter(s, ...)
    if s.ddx == nil or s.ddy == nil then
        return FILTER_MODES.LINEAR(s, ...)
    end
    local m = find_filter_mode(s.ddx, s.ddy)
    return s.filter_modes[m](s, ...)
end

local DEFAULT_SAMPLER<const> = {
    address = {u = ADDRESS_MODES.CLAMP, v = ADDRESS_MODES.CLAMP},
    filter_modes = {
        mip = FILTER_MODES.LINEAR,
        min = FILTER_MODES.LINEAR,
        mag = FILTER_MODES.LINEAR,
    },
    filter = filter,
}

local function create_sampler(s)
    if s then
        return {
            address = {
                u = ADDRESS_MODES[s.address.u],
                v = ADDRESS_MODES[s.address.v],
            },
            filter_modes = {
                mip = FILTER_MODES[s.filter_modes.mip],
                min = FILTER_MODES[s.filter_modes.min],
                mag = FILTER_MODES[s.filter_modes.mag],
            },
            filter = filter,
        }
    end

    return DEFAULT_SAMPLER
end


return {
    DEFAULT = DEFAULT_SAMPLER,
    create = create_sampler,
}