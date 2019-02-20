local ecs = ...
local schema = ecs.schema

local crypt = require "crypt"

schema:typedef("serialize", "string", crypt.uuid)
