local ecs = ...

local math3d = require "math3d"
local const = require "constant"

local function save(v)
    assert(type(v) == "userdata")
    local r = math3d.totable(v)
    r.type = nil
    return r
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
["opt"].s "real[]"
["opt"].r "real[4]"
["opt"].t "real[]"

function srt:init()
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

ecs.component_alias("point", 	"vector")
ecs.component_alias("rotation", "quaternion")
ecs.component_alias("scale",	"vector")
ecs.component_alias("position",	"vector")
ecs.component_alias("direction","vector")
ecs.component_alias("color",    "vector")

ecs.component "frustum"
	['opt'].type "string" ("mat")
	.n "real" (0.1)
	.f "real" (10000)
	['opt'].l "real" (-1)
	['opt'].r "real" (1)
	['opt'].t "real" (1)
	['opt'].b "real" (-1)
	['opt'].aspect "real" (1)
	['opt'].fov "real" (1)
    ['opt'].ortho "boolean" (false)
    