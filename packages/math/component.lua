local ecs = ...

local math3d = require "math3d"

local function save(v)
    assert(type(v) == "userdata")
    return math3d.totable(v)
end

local v = ecs.component_alias("vector", "real[]")
function v:init()
    local n = #self
    if n == 0 or n > 4 then
        error(string.format("vector only accept 1/4 number:%d", n))
    end

    if #self == 1 then
        local vv = self[1]
        self[2], self[3] = vv, vv
        self[4] = 0
    end

    return math3d.ref(math3d.vector(self))
end
local function del(v)
    assert(type(v) == "userdata")
    return {}
end
v.delete = del
v.save = save

local q = ecs.component_alias("quaternion", "real[4]")
function q:init()
    return math3d.ref(math3d.quaternion(self))
end
q.delete = del
q.save = save

local m = ecs.component "matrix"
["opt"].s "vector"
["opt"].r "quaternion"
["opt"].t "vector"
["opt"].v "real[16]"

function m:init()
    if self.v then
        return math3d.ref(math3d.matrix(self.v))
    end

    if self.s or self.r or self.t then
        local r = math3d.ref(math3d.matrix(self))
        self.s, self.r, self.t = nil, nil, nil
        return r
    end
    return math3d.ref(math3d.matrix())
end

m.save = save