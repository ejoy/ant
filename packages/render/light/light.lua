local ecs = ...

ecs.tag "light"

ecs.component "directional_light"
		.intensity "int"	(50)
		.color "color"
['tmp']	.dirty "boolean"	(true)

ecs.component "point_light"
		.intensity "int" (50)
		.color "color"
		.range "real"	(100)
['tmp']	.dirty "boolean"	(true)

ecs.component "spot_light"
		.intensity "int"	(50)
		.color "color"
		.range "real"	(100)
		.angle "real"	(60)
['tmp']	.dirty "boolean"	(true)

ecs.component "ambient_light"
		.mode "string"	("color")
		.factor "real"	(0.3)
		.skycolor "color"
		.midcolor "color"
		.groundcolor "color"
['tmp']	.dirty "boolean"	(true)
