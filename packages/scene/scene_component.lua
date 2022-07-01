local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant
local serialize = import_package "ant.serialize"

local m = ecs.component "scene"

local function init_scene(scene)
	local s, r, t = scene.s, scene.r, scene.t
	if type(s) == "number" then
		s = {s, s, s}
	end
	scene.s = math3d.mark(s and math3d.vector(s) or mc.ONE)
	scene.r = math3d.mark(r and math3d.quaternion(r) or mc.IDENTITY_QUAT)
	scene.t = math3d.mark(t and math3d.vector(t) or mc.ZERO_PT)
	scene.mat = math3d.mark(mc.IDENTITY_MAT)
	scene.worldmat = math3d.mark(mc.IDENTITY_MAT)
	if scene.updir then
		scene.updir = math3d.mark(math3d.vector(scene.updir))
    else
		scene.updir = mc.NULL
	end
	scene.aabb = mc.NULL
	scene.scene_aabb = mc.NULL
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
    math3d.unmark(v.aabb)
    math3d.unmark(v.scene_aabb)
end

function m.marshal(v)
    return serialize.pack(v)
end

function m.unmarshal(s)
    return init_scene(serialize.unpack(s))
end
