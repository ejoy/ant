local ecs = ...
local world = ecs.world
local schema = world.schema

local crypt = require "crypt"

schema:typedef("serialize", "string", crypt.uuid)
