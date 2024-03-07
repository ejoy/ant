local t2d = {}

local t2d_mt = {

}

function t2d.create(t, s)
    assert(t.w and t.h)
    t.sampler = s
    return setmetatable(t, {__index=t2d_mt})
end

return t2d