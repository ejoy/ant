local FEATURES<const> = {
    DRAW_INDIRECT   = 0x00000001,
    GPU_SKINNING    = 0x00000002,
}

local FS = {}

local FEATURE_FLAGS_CACHE = setmetatable({}, {__index=function (t, names)
    local f = 0
    for n in names:gmatch "[%w_]+" do
        local v = FEATURES[n] or error(("Invalid feature name:%s"):format(k))
        f = f | v
    end
    t[names] = f
    return f
end})

function FS.flag_from_featureset(featureset)
    local f = 0
    for k in pairs(featureset) do
        local v = FEATURES[k] or error(("Invalid feature name:%s"):format(k))
        f = f | v
    end
    return f
end

function FS.flag(names)
    return FEATURE_FLAGS_CACHE[names]
end

FS.FEATURES = FEATURES

return FS