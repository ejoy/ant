package.cpath = package.cpath .. ";../?/?.dll" -- for math3d
--package.path = package.path .. ";clibs/?/?.lua"

local rp3d = require "rp3d"
local math3d = require "math3d"

local ms = math3d.new()

local rp3d = rp3d(ms) -- init math adapter

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

local pos = ms:vector()	-- (0,0,0,1)
local ori = ms:quaternion(0, 0, 0, 1)

local object = w:body_create(pos, ori)
w:set_transform(object, pos, ori)

local sphere = w:new_shape("sphere", 10)
w:add_shape(object, sphere, 0)	-- all layer , 0 == 0xffff
local p, o = w:get_aabb(object)
print(ms(p, "V"))
print(ms(o, "V"))

local object2 = w:body_create(ms:vector(10,10,10))
local box = w:new_shape("box", 10)	-- rad / can also be (10,20,30)
w:add_shape(object2, box , 1<<0)	-- add to layer 0
local capsule = w:new_shape("capsule", 10, 20)	-- rad/height
w:add_shape(object2, capsule, 1<<1, ms:vector(0,20,0))	-- add to layer 1

local p, o = w:get_aabb(object2)
print(ms(p, "V"))
print(ms(o, "V"))


print(w:test_overlap(object))	-- test all layer
print(w:test_overlap(object,1<<0))	-- test layer 0
print(w:test_overlap(object,1<<1))	-- test layer 1

local hit, norm = w:raycast(ms:vector(100,100,100), ms:vector(0,0,0))
if hit then
	print("Hit position", ms(hit, "V"))
	print("Hit normal", ms(norm, "V"))
end

w:body_destroy(object)
w:body_destroy(object2)
