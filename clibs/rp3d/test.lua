package.cpath = package.cpath .. ";../?/?.dll" -- for math3d

local rp3d = require "rp3d"
local math3d = require "math3d"

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

local ms = math3d.new()

rp3d.init(ms)	-- init math adapter, shapes manager, etc.

local pos = ms:vector()	-- (0,0,0,1)
local ori = ms:quaternion(0, 0, 0, 1)

local object = w:body_create(pos, ori)
w:set_transform(object, pos, ori)

local sphere = w:new_shape("sphere", 10)
w:add_shape(object, sphere)
local p, o = w:get_aabb(object)
print(ms(p, "V"))
print(ms(o, "V"))

local object2 = w:body_create(ms:vector(10,10,10))
local box = w:new_shape("box", 10)	-- rad / can also be (10,20,30)
w:add_shape(object2, box)
local capsule = w:new_shape("capsule", 10, 20)	-- rad/height
w:add_shape(object2, capsule, ms:vector(0,20,0))

local p, o = w:get_aabb(object2)
print(ms(p, "V"))
print(ms(o, "V"))


print(w:test_overlap(object2))

w:body_destroy(object)
