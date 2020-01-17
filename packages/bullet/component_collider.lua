local ecs = ...
local world = ecs.world

local physic = assert(world.args.Physics)
local physicworld = physic.world
local ms = import_package "ant.math".stack


local function shape_delete(shape)
	if shape.handle and shape.needdel ~= false then
		physicworld:del_shape(shape.handle)
	end
end

local function shape_new(shapetype)
	return function (shape)
		shape.handle = physicworld:new_shape(shapetype, shape)
		return shape
	end
end

local p = ecs.component "plane_shape"
	.origin "position"
	.normal "real[3]" {0, 1, 0}
	.distance "real" (1)
p.init = shape_new "plane"
p.delete = shape_delete

local s = ecs.component "sphere_shape"
	.radius "real" (1)
	.origin "position"
s.init = shape_new "sphere"
s.delete = shape_delete

local b = ecs.component "box_shape"
	.origin "position"
	.size "real[3]" {1, 1, 1}
b.init = shape_new "box"
b.delete = shape_delete

local c = ecs.component "capsule_shape"
	.origin "position"
	.radius "real" (1)
	.height "real" (1)
	.axis 	"string" "Y"
c.init = shape_new "capsule"
c.delete = shape_delete

local C = ecs.component "compound_shape"
	.origin "position"
	["opt"].plane "plane_shape[]"
	["opt"].sphere "sphere_shape[]"
	["opt"].box "box_shape[]"
	["opt"].capsule "capsule_shape[]"
	["opt"].compound "compound_shape[]"

function C:init()
	self.handle = physicworld:new_shape("compound", self)
	local function check_add_child(shape)
		if not shape then
			return
		end
		for _, sh in ipairs(shape) do
			physicworld:add_to_compound(self.handle, sh.handle, sh.origin)
		end
	end
	check_add_child(self.plane)
	check_add_child(self.shape)
	check_add_child(self.box)
	check_add_child(self.capsule)
	check_add_child(self.compound)
	return self
end

C.delete = shape_delete


local collcomp = ecs.component "collider"
	["opt"].user_idx "int"
	["opt"].plane "plane_shape"
	["opt"].sphere "sphere_shape"
	["opt"].box "box_shape"
	["opt"].capsule "capsule_shape"
	["opt"].compound "compound_shape"

function collcomp:init()
	local function add_shape(shape)
		if not shape then
			return
		end
		if self.handle then
			error "collider can only have one shape"
		end
		self.center = shape.origin
		self.handle = physicworld:new_obj(shape.handle)
		physicworld:add_obj(self.handle)
	end
	add_shape(self.plane)
	add_shape(self.sphere)
	add_shape(self.box)
	add_shape(self.capsule)
	add_shape(self.compound)
	if not self.handle then
		error "shape cannot be empty"
	end
	return self
end

function collcomp:delete()
	if self.handle then
		physicworld:del_obj(self.handle)
	end
end

local cp = ecs.policy "collider"
cp.require_component "transform"
cp.require_component "collider"
cp.require_system "ant.bullet|collider_system"

local cp = ecs.policy "collider.character"
cp.require_policy "collider"
cp.require_system "ant.bullet|character_collider_system"

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
