local ecs = ...

local math3d = require "math3d"

local function save(v)
    assert(type(v) == "userdata")
    local r = math3d.totable(v)
    r.type = nil
    return r
end

local v = ecs.component "vector"

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

v.save = save

local q = ecs.component "quaternion"

function q:init()
    return math3d.ref(math3d.quaternion(self))
end
q.save = save

local m = ecs.component "matrix"

function m:init()
    return math3d.ref(math3d.matrix(self))
end

m.save = save
