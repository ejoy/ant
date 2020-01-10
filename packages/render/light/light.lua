local ecs = ...

ecs.component_alias("light", "string")

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

for _, lighttype in ipairs {
	"directional",
	"point",
	"spot",
	"ambient",
} do
	local policyname = "light." .. lighttype
	local p = ecs.policy(policyname)
	p.require_component "light"
	if lighttype ~= "ambient" then
		p.require_component "transform"
	end
	
	local lightname = lighttype .. "_light"
	p.require_component(lightname)

	local transname = lighttype .. "_transform"
	p.require_transform(transname)

	local t = ecs.transform(transname)
	t.input(lightname)
	t.output "light"

	function t.process(e)
		e.light = lightname
	end
end