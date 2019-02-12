local ecs = ...
local world = ecs.world
local schema = world.schema

ecs.tag "light"

schema:type "directional_light"
	.intensity "int"	(50)
	.color "color"

schema:type "point_light"
	.intensity "int" (50)
	.color "color"
	.range "real"	(100)

schema:type "spot_light"
	.intensity "int" (50)
	.color "color"
	.range "real"	(100)
	.angle "real"	(60)

schema:type "ambient_light"
	.mode "string" ("color")
	.factor "real" (0.3)
	.skycolor "color"
	.midcolor "color"
	.groundcolor "color"

for _, ltype in ipairs {
	"directional_light", 
	"point_light", 
	"spot_light",
	"ambient_light"} do
	local l = ecs.component(ltype)
	function l:init()
		self.dirty = true
		return self
	end
end
