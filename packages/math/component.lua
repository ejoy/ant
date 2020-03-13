local ecs = ...

local math3d = require "math3d"

for _, t in ipairs {
    {"vector",      "real[4]", "v4"},
    {"matrix",      "real[16]", "m4"},
    {"quaternion",  "real[4]", "quat"}
} do
    local typename, typedef = t[1], t[2]
    local m = ecs.component_alias(typename, typedef)
    function m.init(v)
        return math3d.ref(math3d[typename](v))
    end

    function m.save(v)
        assert(type(v) == "userdata")
        return math3d.totable(v)
    end
end