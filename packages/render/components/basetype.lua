local ecs = ...
local world = ecs.world
local schema = world.schema

schema:primtype("int", 0)
schema:primtype("real", 0.0)
schema:primtype("string", "")
schema:primtype("boolean", false)
