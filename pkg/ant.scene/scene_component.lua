local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant
local serialize = import_package "ant.serialize"

local m = ecs.component "scene"

local function equal_vec3(a, b)
	if type(a) == "table" then
		return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
	end
end

local function equal_quat(a, b)
	if type(a) == "table" then
		return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
	end
end

local function init_scene(scene)
	local s, r, t = scene.s, scene.r, scene.t
	if type(s) == "number" then
		s = {s, s, s}
	end
	scene.s = mc.ONE
	scene.r = mc.IDENTITY_QUAT
	scene.t = mc.ZERO_PT
	if s and not equal_vec3(s, mc.T_ONE) then
		scene.s = math3d.mark(math3d.vector(s))
	end
	if r and not equal_quat(r, mc.T_IDENTITY_QUAT) then
		scene.r = math3d.mark(math3d.quaternion(r))
	end
	if t and not equal_vec3(t, mc.T_ZERO_PT) then
		scene.t = math3d.mark(math3d.vector(t))
	end
	scene.mat = mc.NULL
	scene.worldmat = mc.NULL
	if scene.updir then
		scene.updir = math3d.mark(math3d.vector(scene.updir))
	else
		scene.updir = mc.NULL
	end
	scene.parent = scene.parent or 0
	return scene
end

function m.init(v)
    return init_scene(v)
end

function m.remove(v)
    math3d.unmark(v.s)
    math3d.unmark(v.r)
    math3d.unmark(v.t)
    math3d.unmark(v.mat)
    math3d.unmark(v.worldmat)
    math3d.unmark(v.updir)
end

function m.marshal(scene)
	return serialize.pack(init_scene(scene))
end

function m.unmarshal(s)
	local scene = serialize.unpack(s)
    math3d.mark(scene.s)
    math3d.mark(scene.r)
    math3d.mark(scene.t)
    math3d.mark(scene.updir)
	return scene
end

local b = ecs.component "bounding"

local function init_bounding(v)
	if not v then
		v = {}
	end
	if v.aabb then
		v.aabb = math3d.mark(math3d.aabb(v.aabb[1], v.aabb[2]))
		v.scene_aabb = math3d.mark(math3d.aabb())
	else
		v.aabb = mc.NULL
		v.scene_aabb = mc.NULL
	end
	return v
end
function b.init(v)
	return init_bounding(v)
end

function b.remove(v)
    math3d.unmark(v.aabb)
    math3d.unmark(v.scene_aabb)
end

function b.marshal(v)
	return serialize.pack(init_bounding(v))
end

function b.unmarshal(v)
	local bounding = serialize.unpack(v)
	math3d.mark(bounding.aabb)
	math3d.mark(bounding.scene_aabb)
	return bounding
end
