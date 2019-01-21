local ecs = ...
local world = ecs.world
local schema = world.schema

schema:userdata "primitive_filter"
local primitive_filter = ecs.component_v2 "primitive_filter"

function primitive_filter:init()
	return { result = {} }
end
