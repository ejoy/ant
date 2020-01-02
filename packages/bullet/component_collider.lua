local ecs = ...
local world = ecs.world

local physic = assert(world.args.Physics)
local physicworld = physic.world
local ms = import_package "ant.math".stack

ecs.component_alias("collider_tag", "string")

local coll = ecs.component "collider"
	.center "real[3]" {0, 0, 0}
	["opt"].is_tigger "boolean" (true)
	["opt"].user_idx "int"

function coll:delete()
	local handle = self.handle
	if handle then
		physicworld:del_obj(handle)
	end
end

local function shape_delete(shape)
	if shape.handle then
		physicworld:del_shape(shape.handle)
	end
end

local function shape_new(shapetype)
	return function (shape)
		shape.type = shapetype
		shape.handle = physicworld:new_shape(shapetype, shape)
		return shape
	end
end

local p = ecs.component "plane_shape"
	.normal "real[3]" {0, 1, 0}
	.distance "real" (1)
p.init = shape_new "plane"
p.delete = shape_delete

local s = ecs.component "sphere_shape"
	.radius "real" (1)
s.init = shape_new "sphere"
s.delete = shape_delete

local b = ecs.component "box_shape"
	.size "real[3]" {1, 1, 1}
b.init = shape_new "box"
b.delete = shape_delete

local c = ecs.component "capsule_shape"
	.radius "real" (1)
	.height "real" (1)
	.axis 	"string" "Y"
c.init = shape_new "capsule"
c.delete = shape_delete

local C = ecs.component "custom_shape"
C.init = shape_new "compound"
C.delete = shape_delete

local char = ecs.component "character_shape"
	.spheres"sphere_shape[]"
	.boxes 	"box_shape[]"
	.customs"custom_shape[]"

function char:init()
	self.type = "character"
	for _, sshape in ipairs(self.spheres) do
		shape_new "sphere"(sshape)
	end

	for _, bshape in ipairs(self.boxes) do
		shape_new "box"(bshape)
	end

	for _, cshape in ipairs(self.customs) do
		shape_new "compound"(cshape)
	end

	return self
end

for _, name in ipairs {
	"plane",
	"sphere",
	"box",
	"capsule",
	"custom",
} do
	local collider_name = name .. "_collider"
	local shape_name = name .. "_shape"
	local collcomp = ecs.component(collider_name)
		.collider "collider"
		.shape(shape_name)

	function collcomp:delete()
		self.shape.handle = nil	-- collider object has own this shape handle
	end

	local trans_name = name .. "_transform"
	local t = ecs.transform(trans_name)
	t.input "transform"
	t.input(collider_name)
	t.output "collider_tag"
	function t.process(e)
		local cc = e[collider_name]
		local shapehandle = cc.shape.handle
		local collider = cc.collider
		local object = physicworld:new_obj(shapehandle)
		physicworld:add_obj(object)
		collider.handle = object

		e.collider_tag = collider_name
	end

	local policy_name = "collider." .. name
	local cp = ecs.policy(policy_name)
	cp.require_component "transform"
	cp.require_component "collider_tag"
	cp.require_component(collider_name)
	cp.require_transform(trans_name)
end

local math3d_adapter = require "math3d.adapter"
local mathadapter_util = import_package "ant.math.adapter"
mathadapter_util.bind("bullet", function ()
	local bw_mt 			= getmetatable(physicworld)
	bw_mt.set_obj_transform = math3d_adapter.matrix(ms, bw_mt.set_obj_transform, 3)
	bw_mt.set_obj_position 	= math3d_adapter.vector(ms, bw_mt.set_obj_position, 3)
	bw_mt.set_obj_rotation 	= math3d_adapter.vector(ms, bw_mt.set_obj_rotation, 3)
	bw_mt.update_obj_scale  = math3d_adapter.vector(ms, bw_mt.update_obj_scale, 4)
	bw_mt.add_to_compound	= math3d_adapter.vector(ms, bw_mt.add_to_compound, 4)
	bw_mt.raycast		 	= math3d_adapter.vector(ms, bw_mt.raycast, 2)
end)
