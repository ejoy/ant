local ecs = ...
local world = ecs.world

local base_entity = ecs.policy "base_entity"
base_entity.require_component "name"
base_entity.require_component "transform"
base_entity.require_component "serialize"