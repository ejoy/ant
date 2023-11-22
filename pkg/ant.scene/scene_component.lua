local ecs = ...

local math3d = require "math3d"
local mc = import_package "ant.math".constant
local serialization = require "bee.serialization"

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

function m.init(scene)
	local s, r, t = scene.s, scene.r, scene.t
	if type(s) == "number" then
		s = {s, s, s}
	end
	scene.s = mc.ONE
	scene.r = mc.IDENTITY_QUAT
	scene.t = mc.ZERO_PT
	if s and not equal_vec3(s, mc.T_ONE) then
		scene.s = math3d.marked_vector(s)
	end
	if r and not equal_quat(r, mc.T_IDENTITY_QUAT) then
		scene.r = math3d.marked_quat(r)
	end
	if t and not equal_vec3(t, mc.T_ZERO_PT) then
		scene.t = math3d.marked_vector(t)
	end
	scene.mat = mc.NULL
	scene.worldmat = mc.NULL
	if scene.updir then
		scene.updir = math3d.marked_vector(scene.updir)
	else
		scene.updir = mc.NULL
	end
	scene.parent = scene.parent or 0
	scene.movement = 0
	return scene
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
	return serialization.packstring(scene)
end

function m.demarshal(s)
	local scene = serialization.unpack(s)
	math3d.unmark(scene.s)
	math3d.unmark(scene.r)
	math3d.unmark(scene.t)
	math3d.unmark(scene.updir)
end

function m.unmarshal(s)
	local scene = serialization.unpack(s)
    math3d.mark(scene.s)
    math3d.mark(scene.r)
    math3d.mark(scene.t)
    math3d.mark(scene.updir)
	return scene
end
