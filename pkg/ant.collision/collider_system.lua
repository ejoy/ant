local ecs = ...
local world = ecs.world
local w = world.w

local mc 		= import_package "ant.math".constant

local math3d = require "math3d"
local rp3d = require "rp3d"

rp3d.init()

local rp3d_world = rp3d.create_world {
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
	nbMaxContactManifolds = 3,
	cosAngleSimilarContactManifold = 0.95,
--	logger = { Level = "Error", Format = "Text" },
}

local function sphere_shape(shape)
	return rp3d_world:new_shape("sphere", shape.radius)
end

local function box_shape(shape)
	return rp3d_world:new_shape("box", table.unpack(shape.size))
end

local function capsule_shape(shape)
	return rp3d_world:new_shape("capsule", shape.radius, shape.height)
end

local icoll = {}

local function set_obj_transform(obj, t, r)
	rp3d_world:set_transform(obj, t, r)
end

function icoll.test(e, srt)
	local collider = e.collider
	if not collider then
		return false
	end
	if srt then
		set_obj_transform(e.collider._handle, srt.t, srt.r)
	end
	local hit = rp3d_world:test_overlap(e.collider._handle)
	if srt then
		local _, r, t = math3d.srt(e.transform)
		set_obj_transform(e.collider._handle, t, r)
	end
	return hit
end

function icoll.raycast(ray)
	return rp3d_world:raycast(ray[1], ray[2], ray.mask)
end

local collider_sys = ecs.system "collider_system"

function collider_sys:update_collider_transform()
	for v in w:select "scene_changed collider:in scene:in" do
		local _, r, t = math3d.srt(v.scene.worldmat)
		if v.collider._handle then
			set_obj_transform(v.collider._handle, t, r)
		end
    end
end

function collider_sys:entity_init()
	for e in w:select "INIT collider:in" do
		local collider = e.collider
		collider._handle = rp3d_world:body_create(mc.ZERO_PT, mc.IDENTITY_QUAT)
		local function add_shape(shape, constructor)
			if shape then
				for _, sh in ipairs(shape) do
					rp3d_world:add_shape(collider._handle, constructor(sh), math3d.vector(sh.origin))
				end
			end
		end
		add_shape(collider.sphere,  sphere_shape)
		add_shape(collider.box,     box_shape)
		add_shape(collider.capsule, capsule_shape)
	end
end

function collider_sys:entity_remove()
	for e in w:select "REMOVED collider:in" do
		local collider = e.collider
		if collider._handle then
			rp3d_world:body_destroy(collider._handle)
		end
	end
end

return icoll
