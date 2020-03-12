package.cpath = package.cpath .. ";../?/?.dll"
package.path = package.path .. ";packages/collision/?.lua"

local rp3d = require "rp3d"
local math3d = require "math3d"

rp3d.init() -- init math adapter, shape interning

local w = rp3d.collision_world {
	worldName = "world",
	persistentContactDistanceThreshold = 0.03,
	defaultFrictionCoefficient = 0.3,
	defaultBounciness = 0.5,
	restitutionVelocityThreshold = 1.0,
	defaultRollingRestistance = 0,
	isSleepingEnabled = true,
	defaultVelocitySolverNbIterations = 10,
	defaultPositionSolverNbIterations = 5,
	defaultTimeBeforeSleep = 1.0,
	defaultSleepLinearVelocity = 0.02,
	defaultSleepAngularVelocity = 3.0 * (math.pi / 180),
	nbMaxContactManifoldsConvexShape = 1,
	nbMaxContactManifoldsConcaveShape = 3,
	cosAngleSimilarContactManifold = 0.95,

--	logger = { Level = "Error", Format = "Text" },
}

local pos = math3d.vector()	-- (0,0,0,1)
local ori = math3d.quaternion(0, 0, 0, 1)

local object = w:body_create(pos, ori)
w:set_transform(object, pos, ori)

local sphere = w:new_shape("sphere", 10)
w:add_shape(object, sphere, 0)	-- all layer , 0 == 0xffff
local p, o = w:get_aabb(object)
print(math3d.tostring(p))
print(math3d.tostring(o))

local object2 = w:body_create(math3d.vector(10,10,10))
local box = w:new_shape("box", 10)	-- rad / can also be (10,20,30)
w:add_shape(object2, box , 1<<0)	-- add to layer 0
local capsule = w:new_shape("capsule", 10, 20)	-- rad/height
w:add_shape(object2, capsule, 1<<1, math3d.vector(0,20,0))	-- add to layer 1

local p, o = w:get_aabb(object2)
print(math3d.tostring(p))
print(math3d.tostring(o))


print(w:test_overlap(object))	-- test all layer
print(w:test_overlap(object,1<<0))	-- test layer 0
print(w:test_overlap(object,1<<1))	-- test layer 1

local hit, norm = w:raycast(math3d.vector(100,100,100), math3d.vector(0,0,0))
if hit then
	print("Hit position", math3d.tostring(hit))
	print("Hit normal", math3d.tostring(norm))
end

local hit, norm = w:raycast(math3d.vector(100,100,100), math3d.vector(0,0,0), object)
if hit then
	print("Hit sphere position", math3d.tostring(hit))
	print("Hit sphere normal", math3d.tostring(norm))
end

w:body_destroy(object)
w:body_destroy(object2)

-- heightfield
do
	local heightfield = math3d.ref()
	heightfield.m = math3d.matrix(
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0)
	local height_scaling = 1
	local scaling = 1
	local hf_shape = w:new_shape("heightfield", 4, 4, 0, 1, heightfield.p, height_scaling, scaling)

	local hf_obj = w:body_create(math3d.vector(0, 0, 0, 1), math3d.quaternion(0, 0, 0, 1))
	w:add_shape(hf_obj, hf_shape, 0)

	local h, n = w:raycast(math3d.vector(0, 1, 0, 1), math3d.vector(0, -1, 0, 1))
	if h then
		print("height field shape hitted, point:%s, normal:%s", math3d.tostring(h), math3d.tostring(n))
	end
	w:body_destroy(hf_obj)
end
