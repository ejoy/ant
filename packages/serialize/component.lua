local ecs = ...

local crypt = require "crypt"

ecs.component_alias("serialize", "string", crypt.uuid)

local p = ecs.policy "serialize"
p.require_component "serialize"
