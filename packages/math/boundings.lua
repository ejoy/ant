local boundings = {}; boundings.__index = boundings

local mathbaselib = require "math3d.baselib"
local ms = require "stack"

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

function boundings:isvalid()
    return ms:equal(self.aabb.min, self.aabb.max)
end

function boundings:merge(other)
    mathbaselib.bounding_merge(self, other)
end

function boundings:append_point(pt)
    mathbaselib.bounding_append(self, pt)
end

function boundings:transform(trans)
    mathbaselib.bounding_transform(self, trans)
end

function boundings:interset_plane(plane)
    mathbaselib.bounding_interset(self, plane, "plane")
end

function boundings:interset_frustum(frustum)
    mathbaselib.bounding_interset(self, frustum, "frustum")
end

return boundings