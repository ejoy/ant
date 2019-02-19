local ecs = ...
local world = ecs.world
local schema = world.schema

schema:typedef("hierarchy", "resource")

schema:typedef("hierarchy_name_mapper", "entityid{}")
