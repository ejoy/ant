local boundings = {}; boundings.__index = boundings

local mathbaselib = require "math3d.baselib"

function boundings.new(min, max)
    return setmetatable(mathbaselib.boundings(min, max), boundings)
end

function boundings:__gc()
    self.aabb.min = nil
    self.aabb.max = nil

    self.aabb   = nil
    self.sphere = nil
    self.obb    = nil
end


return boundings