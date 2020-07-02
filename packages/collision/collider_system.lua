local ecs = ...
local world = ecs.world

local mc 		= import_package "ant.math".constant

local math3d = require "math3d"
local rp3d = require "rp3d"
local mathadapter = import_package "ant.math.adapter"

mathadapter.bind("collision", function() rp3d.init() end)

local w = rp3d.create_world {
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
	return w:new_shape("sphere", shape.radius)
end

local function box_shape(shape)
	return w:new_shape("box", table.unpack(shape.size))
end

local function capsule_shape(shape)
	return w:new_shape("capsule", shape.radius, shape.height)
end

local function terrain_shape(self)
	self.up_axis 		= self.up_axis or "Y"
	self.min_height 	= self.min_height or 0
	self.max_height 	= self.max_height or 0
	self.height_scaling = self.height_scaling or 1
	self.scaling 		= self.scaling or 1
	return self
end

local tcb = ecs.transform "terrain_collider_transform"

local iterrain = world:interface "ant.terrain|terrain"

function tcb.process_entity(e)
	local terraincomp = e.terrain
	local tc = e.collider

	local shape = tc.terrain[1]

	if shape.min_height == nil or  shape.max_height == nil then
		 local min, max = iterrain.calc_min_max_height(terraincomp)
		 shape.min_height = shape.min_height or min
		 shape.max_height = shape.max_height or max
	end

	local scaling = shape.scaling
	local terrain_grid_unit = terraincomp.grid_unit
	local terrain_scaling = math3d.vector(terrain_grid_unit, 1, terrain_grid_unit, 0)
	scaling = scaling and math3d.mul(scaling, terrain_scaling) or terrain_scaling

	local heightfield = terraincomp.heightfield
	local hf_width, hf_height = heightfield[1], heightfield[2]
	local hf_data = heightfield[3]
	shape._handle = w:new_shape("heightfield", hf_width, hf_height, shape.min_height, shape.max_height, hf_data, shape.height_scaling, scaling)

	w:add_shape(tc._handle, shape._handle, 0, shape.origin)
	local aabbmin, aabbmax = w:get_aabb(tc.handle)
	terraincomp.bounding = {
		aabb = math3d.ref(math3d.aabb(aabbmin, aabbmax))
	}
end

local collcomp = ecs.component "collider"

function collcomp:init()
	self._handle = w:body_create(mc.ZERO_PT, mc.IDENTITY_QUAT)
	local function add_shape(shape, constructor)
		if not shape then
			return
		end
		for _, sh in ipairs(shape) do
			w:add_shape(self._handle, constructor(sh), math3d.vector(sh.origin))
		end
	end
	add_shape(self.sphere,  sphere_shape)
	add_shape(self.box,     box_shape)
	add_shape(self.capsule, capsule_shape)
	--add_shape(self.terrain)
	return self
end

function collcomp:delete()
	if self._handle then
		w:body_destroy(self._handle)
	end
end

local icoll = ecs.interface "collider"

local function set_obj_transform(obj, t, r)
	w:set_transform(obj, t, r)
end

function icoll.test(e, srt)
	local collider = e.collider
	if not collider then
		return false
	end
	set_obj_transform(e.collider._handle, srt.t, srt.r)
	local hit = w:test_overlap(e.collider._handle)
	local _, r, t = math3d.srt(e.transform)
	set_obj_transform(e.collider._handle, t, r)
	return hit
end

function icoll.raycast(ray)
	return w:raycast(ray[1], ray[2], ray.mask)
end

local collider_entity_mapper = {}

function icoll.which_entity(id)
	return collider_entity_mapper[id]
end

local collider_sys = ecs.system "collider_system"

local new_coll_mb = world:sub{"component_register", "collider"}
function collider_sys:data_changed()
	for _, _, eid in new_coll_mb:unpack() do
		local e = world[eid]
		local obj = e.collider._handle
		collider_entity_mapper[obj] = eid
	end
end

local trans_changed_mb = world:sub {"component_changed", "transform"}
local iom = world:interface "ant.objcontroller|obj_motion"
function collider_sys:update_collider_transform()
    for _, _, eid in trans_changed_mb:unpack() do
		local e = world[eid]
		if e.collider then
			local _, r, t = math3d.srt(iom.worldmat(eid))
			set_obj_transform(e.collider._handle, t, r)
		end
    end
end
