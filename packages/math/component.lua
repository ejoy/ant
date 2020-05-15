local ecs = ...

local math3d = require "math3d"
local const = require "constant"

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

local function vector_init(self)
    if type(self) == "userdata" then
        return self
    end
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

local function quaternion_init(self)
    if type(self) == "userdata" then
        return self
    end
    return math3d.ref(math3d.quaternion(self))
end

local srt = ecs.component "srt"

function srt:init()
    assert(type(self) == "table")
    self.s = vector_init(self.s or const.ONE)
    self.r = quaternion_init(self.r or const.IDENTITY_QUAT)
    self.t = vector_init(self.t or const.ZERO_PT)
    return math3d.ref(math3d.matrix(self))
end

function srt:save()
    assert(type(self) == "userdata")
    local s, r, t = math3d.srt(self)
    return {
        s = save(s),
        r = save(r),
        t = save(t),
    }
end

