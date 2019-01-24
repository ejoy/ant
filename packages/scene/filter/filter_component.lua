local ecs = ...
local world = ecs.world
local schema = world.schema

schema:primtype "primitive_filter"
local primitive_filter = ecs.component "primitive_filter"

function primitive_filter:init()
	return { result = {} }
end
