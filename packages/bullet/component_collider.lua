local ecs = ...
local world = ecs.world
local schema = world.schema
    	
--ecs.tag "collider"

schema:type "collider"
	.center "real[3]" {0, 0, 0}
	.is_tigger "boolean" (true)
	.obj_idx "int" (-1)

schema:type "plane_shape"
	.type "string" "plane"
	.normal "real[3]" {0, 1, 0}
	.distance "real" (1)

schema:type "sphere_shape"	
	.radius "real" (1)

schema:type "box_shape"	
	.type "string" "box"
	.size "real[3]" {1, 1, 1}	

schema:type "capsule_shape"	
	.type "string" "capsule"
	.radius "real" (1)
	.height "real" (1)
	.axis "int" (0)	

schema:typedef("cylinder_shape", "capsule_shape")

schema:type "terrain_shape"
	.width "int" (1)
	.height "int" (1)
	.grid_scale "real" (1)
	.height_scale "real" (1)
	.min_height "real" (1)
	.max_height "real" (1)
	.axis "int" (0)
	.datatype "string" ("uchar")
	.flip_quad_edges "boolean" (false)

schema:type "custom_shape"
	.type "string" "compound"	

schema:type "character_shape"
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
	schema:type(collidername)
		.collider "collider"
		.shape(shapename)

	local s = ecs.component(shapename)
	function s:delete()
		local Physics = assert(world.args.Physics)     -- if use message notify, decoupling will be better?		
		Physics:delete_shape(self.handle)
		-- or use message notify mechanism
		print("delete shape", shapename)
	end

	local c = ecs.component(collidername)	
	function c:delete()
		local collider = self.collider
		local Physics = assert(world.args.Physics)
		Physics:delete_object(collider.handle)

		print("delete object", collidername)
	end
end
