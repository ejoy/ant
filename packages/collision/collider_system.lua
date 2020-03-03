local ecs = ...
local world = ecs.world

local ms = import_package "ant.math".stack
local rp3d = require "rp3d"
local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("rp3d", function() rp3d.init(ms) end)

local w = rp3d.collision_world {
	worldName = "world",
	nbMaxContactManifoldsConvexShape = 1,
	nbMaxContactManifoldsConcaveShape = 3,
	cosAngleSimilarContactManifold = 0.95,
--	logger = { Level = "Error", Format = "Text" },
}

local s = ecs.component "sphere_shape"
	.origin "position"
	.radius "real"
function s:init()
	self.handle = w:new_shape("sphere", self.radius)
	return self
end

local b = ecs.component "box_shape"
	.origin "position"
	.size "real[3]"
function b:init()
	self.handle = w:new_shape("box", table.unpack(self.size))
	return self
end

local c = ecs.component "capsule_shape"
	.origin "position"
	.radius "real"
	.height "real"
function c:init()
	self.handle = w:new_shape("capsule", self.radius, self.height)
	return self
end

local ts = ecs.component "terrain_shape"
	.origin "position"
	["opt"].min_height 		"real"
	["opt"].max_height 		"real"
	["opt"].height_scaling	"real"(1.0)
	["opt"].scaling 		"scale"

function ts:init()
	self.up_axis = self.up_axis or "Y"
	self.min_height = self.min_height or 0
	self.max_height = self.max_height or 0
	self.height_scaling = self.height_scaling or 1
	self.scaling = self.scaling or ms:ref "vector" {1, 1, 1, 0}

	return self
end

ecs.component "terrain_collider"
.shape "terrain_shape"

local tc_p = ecs.policy "terrain_collider"
tc_p.require_component "terrain_collider"
tc_p.require_component "terrain"

tc_p.require_transform "terrain_collider_build"

local tcb = ecs.transform "terrain_collider_build"
tcb.input "terrain"
tcb.output "terrain_collider"
tcb.require_interface "ant.terrain|terrain"
local iterrain = world:interface "ant.terrain|terrain"

function tcb.process(e)
	local terraincomp = e.terrain
	local terraincollider = e.terrain_collider

	terraincollider.handle = w:body_create()
	assert(terraincollider.shape.handle == nil)

	local shape = terraincollider.shape

	if shape.min_height == nil or  shape.max_height == nil then
		 local min, max = iterrain.calc_min_max_height(terraincomp)
		 shape.min_height = shape.min_height or min
		 shape.max_height = shape.max_height or max
	end

	local scaling = shape.scaling
	local terrain_grid_unit = terraincomp.grid_unit
	local terrain_scaling = ms({terrain_grid_unit, 1, terrain_grid_unit, 0}, "P")
	scaling = scaling and ms(scaling, terrain_scaling, "*P") or terrain_scaling

	local heightfield = terraincomp.heightfield
	local hf_width, hf_height = heightfield[1], heightfield[2]
	local hf_data = heightfield[3]
	shape.handle = w:new_shape("heightfield", hf_width, hf_height, shape.min_height, shape.max_height, hf_data, shape.height_scaling, scaling)

	w:add_shape(terraincollider.handle, shape.handle, 0, shape.origin)
end

local collcomp = ecs.component "collider"
	["opt"].sphere "sphere_shape[]"
	["opt"].box "box_shape[]"
	["opt"].capsule "capsule_shape[]"

function collcomp:init()
	self.handle = w:body_create()
	local function add_shape(shape)
		if not shape then
			return
		end
		for _, sh in ipairs(shape) do
			w:add_shape(self.handle, sh.handle, 0, sh.origin)
		end
	end
	add_shape(self.sphere)
	add_shape(self.box)
	add_shape(self.capsule)
	return self
end

function collcomp:delete()
	if self.handle then
		w:body_destroy(self.handle)
	end
end

local cp = ecs.policy "collider"
cp.require_component "transform"
cp.require_component "collider"
cp.require_system "ant.collision|collider_system"

local m = ecs.interface "collider"
m.require_system "collider_system"

local function set_obj_transform(obj, srt)
	w:set_transform(obj, srt.t, srt.r)
end

function m.test(e, srt)
	local collider = e.collider
	if not collider then
		return false
	end
	set_obj_transform(e.collider.handle, srt)
	local hit = w:test_overlap(e.collider.handle)
	set_obj_transform(e.collider.handle, e.transform)
	return hit
end

function m.raycast(ray)
	return w:raycast(ray[1], ray[2], ray.mask)
end

local collider_sys = ecs.system "collider_system"

function collider_sys:update_collider_transform()
    for _, eid in world:each "collider" do
        local e = world[eid]
        -- TODO: world transform will not correct when this entity attach on hierarchy tree
        -- we need seprarte update transform from primitive_filter_system
        set_obj_transform(e.collider.handle, e.transform)
    end
end
