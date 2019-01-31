local ecs = ...
local world = ecs.world
local schema = world.schema

local crypt = require "crypt"

schema:typedef("serialize", "string")

local seria_comp = ecs.component "serialize"

function seria_comp:init()
    return crypt.uuid()
end
