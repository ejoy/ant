local ecs = ...

local math3d = require "math3d"
local ms = require "stack"


for _, t in ipairs {
    {"vector",      "real[4]", "v4"},
    {"matrix",      "real[16]", "m4"},
    {"quaternion",  "real[4]", "quat"}
} do
    local typename, typedef, innertype = t[1], t[2], t[3]
    local m = ecs.component_alias(typename, typedef)
    function m.init(v)
        if innertype == "quat" then
            v.type = "q"
        end
        local r = ms:ref(typename)(v)
        return r
    end

    function m.delete(v)
        v(nil)
    end

    function m.save(v)
        assert(type(v) == "userdata")	
        local tt = ms(v, "T")
        assert(type(tt) == "table" and t.type ~= nil)
        assert(t.type == innertype, "vector load function need vector type")
        t.type = nil
    end
end