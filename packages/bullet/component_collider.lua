local ecs = ...
local world = ecs.world

local Physics = assert(world.args.Physics)
local ms = import_package "ant.math".stack

local colliderutil = require "util"

ecs.tag "collider_tag"

local coll = ecs.component "collider"
	.center "real[3]" {0, 0, 0}
	.is_tigger "boolean" (true)

function coll:delete()	
	local handle = self.handle
	if handle then
		local Physics = assert(world.args.Physics)
		Physics:del_obj(handle)
	end
end
	
local objidx_counter = 0
local function collider_obj_idx_creator()
	local oi = objidx_counter
	objidx_counter = objidx_counter + 1
	return oi
end

function coll:init()
	self.obj_idx = collider_obj_idx_creator()
	return self
end

ecs.component "plane_shape"
	.type "string" "plane"
	.normal "real[3]" {0, 1, 0}
	.distance "real" (1)

ecs.component "sphere_shape"	
	.radius "real" (1)

ecs.component "box_shape"	
	.type "string" "box"
	.size "real[3]" {1, 1, 1}	

ecs.component "capsule_shape"	
	.type "string" "capsule"
	.radius "real" (1)
	.height "real" (1)
	.axis "int" (0)	

ecs.component_alias("cylinder_shape", "capsule_shape")

ecs.component "custom_shape"
	.type "string" "compound"	

ecs.component "character_shape"
	.type "string" "compound"
	.spheres "sphere_shape[]"
	.boxes 	"box_shape[]"
	.customs "custom_shape[]"

for _, pp in ipairs {
	{"plane_collider", 	"plane_shape"},
	{"sphere_collider", "sphere_shape"},
	{"box_collider", 	"box_shape"},
	{"capsule_collider","capsule_shape"},
	{"cylinder_collider","cylinder_shape"},	
	{"character_collider", "character_shape" },
} do
	local collidername, shapename = pp[1], pp[2]
	local s = ecs.component(shapename)
	function s:init()
		self.handle = Physics:new_shape(self.type, self)
		return self
	end

	function s:delete()
		if self.handle then
			Physics:del_shape(self.handle)		
		end
	end

	local c = ecs.component(collidername) { depend = "transform" }
		.collider "collider"
		.shape(shapename)

	function c:postinit(e)
		colliderutil.create_collider_comp(Physics, self.shape, self.collider, e.transform)
	end
end

local math3d_adapter = require "math3d.adapter"
local mathadapter_util = import_package "ant.math.adapter"
mathadapter_util.bind("bullet", function ()
	local bw = Physics.world
	local bw_mt = getmetatable(bw)
	bw_mt.new_obj = math3d_adapter.vector(ms, bw_mt.new_obj, 4)
	bw_mt.set_obj_transform = math3d_adapter.vector(ms, bw_mt.set_obj_transform, 3);
	bw_mt.set_obj_position = math3d_adapter.vector(ms, bw_mt.set_obj_position, 3);
	bw_mt.set_obj_rotation = math3d_adapter.vector(ms, bw_mt.set_obj_rotation, 3);
end)
