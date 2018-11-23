local ecs = ...
local world = ecs.world

ecs.import "render.entity_rendering_system"

local generator = ecs.system "geometry_generator"

function generator.update()
	print("generator")
end