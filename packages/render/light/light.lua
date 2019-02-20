local ecs = ...
local world = ecs.world
local schema = world.schema

ecs.tag "light"

schema:type "directional_light"
		.intensity "int"	(50)
		.color "color"
['tmp']	.dirty "boolean"	(true)

schema:type "point_light"
		.intensity "int" (50)
		.color "color"
		.range "real"	(100)
['tmp']	.dirty "boolean"	(true)

schema:type "spot_light"
		.intensity "int"	(50)
		.color "color"
		.range "real"	(100)
		.angle "real"	(60)
['tmp']	.dirty "boolean"	(true)

schema:type "ambient_light"
		.mode "string"	("color")
		.factor "real"	(0.3)
		.skycolor "color"
		.midcolor "color"
		.groundcolor "color"
['tmp']	.dirty "boolean"	(true)
