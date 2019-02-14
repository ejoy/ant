local ecs = ...

local world = ecs.world
local schema = world.schema


schema:type "terrain"
	.heightmap "resource"
	

local terrain_system = ecs.system "terrain_system"

function terrain_system:init()

end

function terrain_system:update()

end