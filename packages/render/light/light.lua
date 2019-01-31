local ecs = ...
local world = ecs.world
local schema = world.schema

ecs.tag "directional_light"
ecs.tag "point_light"
ecs.tag "spot_light"

schema:type "light"
		.type "string" "point" 	-- "spot", "directional", "ambient"
		.intensity "int" (50)
		.color "color"
["opt"]	.angle "int" (360)
["opt"]	.range "int" (100)
