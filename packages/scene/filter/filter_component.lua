local ecs = ...
local world = ecs.world
local schema = world.schema

schema:type "primitive_filter"
local primitive_filter = ecs.component "primitive_filter"

function primitive_filter:init()
	self.result = {}
	return self
end
