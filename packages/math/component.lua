local ecs = ...

local math3d = require "math3d"
local const = require "constant"

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

local m = ecs.component_alias("matrix", "real[16]")
function m:init()
    return math3d.ref(math3d.matrix(self))
end

m.save = save

local srt = ecs.component "srt"
["opt"].s "vector"
["opt"].r "quaternion"
["opt"].t "vector"

function srt:init()
    self.s = self.s or const.ONE
    self.r = self.r or const.IDENTITY_QUAT
    self.t = self.t or const.ZERO_PT
    local r = math3d.ref(math3d.matrix(self))
    -- s, r, t only for init
    self.s, self.r, self.t = nil, nil, nil
    return r
end

function srt:save()
    assert(type(self) == "userdata")
    local s, r, t = math3d.srt(self)
    return {
        s = s,
        r = r,
        t = t,
    }
end