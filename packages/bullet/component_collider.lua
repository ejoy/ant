local ecs = ...
local world = ecs.world
		
local ms = import_package "ant.math".stack
ecs.tag "collider_tag"

ecs.component "collider"
	.center "real[3]" {0, 0, 0}
	.is_tigger "boolean" (true)
	.obj_idx "int" (-1)

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
	ecs.component(collidername)
		.collider "collider"
		.shape(shapename)

	local s = ecs.component(shapename)
	function s:init()
		local Physics = assert(world.args.Physics)
		self.handle = Physics:create_shape(self.type, self)
		return self
	end

	function s:delete()
		if self.handle then
			local Physics = assert(world.args.Physics)			
			Physics:delete_shape(self.handle)		
		end
	end

	local c = ecs.component(collidername)

	function c:delete()
		local collider = self.collider
		if collider.handle then
			local Physics = assert(world.args.Physics)
			Physics:delete_object(collider.handle)
		end
	end
end

local collider_post_init = ecs.system "collider_post_init"

function collider_post_init:post_init()
	local Physics = assert(world.args.Physics)
	for eid in world:each_new("collider_tag") do
		local e = world[eid]
		local function get_collider(e)
			for _, name in ipairs {
				"plane_collider", "sphere_collider", "box_collider",
				"capsule_collider", "cylinder_collider", "terrain_collider",
				"character_collider",
			} do
				local c = e[name]
				if c then
					return c
				end
			end
		end

		local collidercomp = get_collider(e)
		if collidercomp == nil then
			error("using collider_tag but do not define any collider")
		end

		local collider = collidercomp.collider
		collider.obj_idx = eid
		local shapeinfo = collidercomp.shape
		local pos = ms(e.position, collider.center, "+m")
		assert(shapeinfo.handle == nil)
		assert(collider.handle == nil)
		shapeinfo.handle, collider.handle = Physics:create_collider(shapeinfo.type, shapeinfo, eid, pos, ms(e.rotation, "qm"))
	end
end