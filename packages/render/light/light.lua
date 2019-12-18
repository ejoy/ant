local ecs = ...

ecs.component_alias("light", "string")

local dl = ecs.policy "directional_light_policy"
dl.require_component "light"

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
	"directional_light",
	"point_light",
	"spot_light",
	"ambient_light",
} do
	local p = ecs.policy(lighttype)
	p.require_component "light"
	if lighttype ~= "ambient_light" then
		p.require_component "transform"
	end
	p.require_component(lighttype)
	p.require_transform(lighttype)

	local t = ecs.transform(lighttype)
	t.input(lighttype)
	t.output "light"

	function t.process(e)
		e.light = lighttype
	end
end