local t2d = {}
--TODO: use surface object to implement all the features

local surface = require "surface"
local S = require "sampler"
local F = require "format"


local math3d = require "math3d"

local t2d_mt = {
    --ix/iy are base 1
    load = function (self, ix, iy)
        local pitch = self.pitch or self.w
        local offset = ((iy-1) * pitch + ix-1) * self.texelsize+1
        local t = F[self.fmt]:unpack(self.data, offset)
        assert(t[#t]-offset == self.texelsize)
        t[#t] = nil
        for i=#t+1, 4 do
            t[i] = 0.0
        end
        return math3d.vector(t)
    end,
    sample = function (self, u, v)
        return surface.sample(self, self.sampler, u, v)
    end,
}

function t2d.create(t, s)
    assert(t.w and t.h)
    assert(t.data)
    
    t.fmt = t.fmt or "RGBA32F"
    local f = F[t.fmt]
    if f == nil then
        error(("Not support texture format:%s"):format(t.fmt))
    end
    t.texelsize = f.bpp // 8

    t.mip = t.mip or 0
    t.layer = t.layer or 1
    t.sampler = S.create(s)
    return setmetatable(t, {__index=t2d_mt})
end

return t2d