local ecs = ...
local world = ecs.world

local physic = assert(world.args.Physics)
local physicworld = physic.world
local ms = import_package "ant.math".stack

local colliderutil = require "util"

ecs.component_alias("collider_tag", "string")

local coll = ecs.component "collider"
	.center "real[3]" {0, 0, 0}
	.is_tigger "boolean" (true)
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

for _, pp in ipairs {
	{"plane_collider", 	  "plane_shape",},
	{"sphere_collider",   "sphere_shape",},
	{"box_collider", 	  "box_shape", },
	{"capsule_collider",  "capsule_shape",},
	{"character_collider","character_shape",},
} do
	local collidername, shapename = pp[1], pp[2]

	local c = ecs.component(collidername) { depend = {"rendermesh", "transform", "collider_tag"} }
		.collider "collider"
		.shape(shapename)

	function c:postinit(e)
		local shape = self.shape
		local collider = self.collider
		colliderutil.create_collider_comp(physicworld, shape, collider, e.transform)
	end

	function c:delete()
		self.shape.handle = nil	-- collider object has own this shape handle
	end
end

local capsule_policy = ecs.policy "capsule"
capsule_policy.require_component "collider_tag"
capsule_policy.require_component "capsule_collider"
capsule_policy.require_transform "capsule_transform"

local ct = ecs.transform "capsule_transform"
ct.input "capsule_collider"
ct.output "collider_tag"

function ct.process(e)
    e.collider_tag = "capsule_collider"
end

local math3d_adapter = require "math3d.adapter"
local mathadapter_util = import_package "ant.math.adapter"
mathadapter_util.bind("bullet", function ()
	local bw_mt 			= getmetatable(physicworld)
	bw_mt.new_obj 			= math3d_adapter.vector(ms, bw_mt.new_obj, 3)
	bw_mt.set_obj_transform = math3d_adapter.vector(ms, bw_mt.set_obj_transform, 3)
	bw_mt.set_obj_position 	= math3d_adapter.vector(ms, bw_mt.set_obj_position, 3)
	bw_mt.set_obj_rotation 	= math3d_adapter.vector(ms, bw_mt.set_obj_rotation, 3)
	bw_mt.set_shape_scale 	= math3d_adapter.vector(ms, bw_mt.set_shape_scale, 3)
	bw_mt.update_object_shape = math3d_adapter.vector(ms, bw_mt.update_object_shape, 4)
	bw_mt.raycast		 	= math3d_adapter.vector(ms, bw_mt.raycast, 2)
end)
