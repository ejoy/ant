local ecs = ...
local world = ecs.world

local Physics = assert(world.args.Physics)
local ms = import_package "ant.math".stack
ecs.tag "collider_tag"

local coll = ecs.component "collider"
	.center "real[3]" {0, 0, 0}
	.is_tigger "boolean" (true)
	
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

ecs.component "terrain_shape"
	.width "int" (1)
	.height "int" (1)
	.grid_scale "real" (1)
	.height_scale "real" (1)
	.min_height "real" (1)
	.max_height "real" (1)
	.axis "int" (0)
	.datatype "string" ("uchar")
	.flip_quad_edges "boolean" (false)

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
	{"terrain_collider","terrain_shape"},
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
		local collider = self.collider
		local shapeinfo = self.shape

		local trans = e.transform
		local pos = ms(trans.t, collider.center, "+P")
		
		assert(collider.handle == nil)
		collider.handle = Physics:create_collider(assert(shapeinfo.handle), collider.obj_idx, pos, ms(trans.r, "qP"))
	end

	function c:delete()
		local collider = self.collider
		if collider.handle then
			local Physics = assert(world.args.Physics)
			Physics:del_obj(collider.handle)
		end
	end
end