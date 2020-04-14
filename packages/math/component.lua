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

local srt = ecs.component "srt"
["opt"].s "vector"
["opt"].r "quaternion"
["opt"].t "vector"

function srt:init()
    self.s = self.s or const.ONE
    self.r = self.r or const.IDENTITY_QUAT
    self.t = self.t or const.ZERO_PT
    return math3d.ref(math3d.matrix(self))
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
    

local tp = ecs.policy "transform"
tp.require_component "transform"

local trans = ecs.component "transform"
    .srt "srt"
function trans:init()
    self.world = math3d.ref(self.srt)
    return self
end