local ecs = ...

local crypt = require "crypt"

ecs.component_alias("serialize", "string", crypt.uuid)
