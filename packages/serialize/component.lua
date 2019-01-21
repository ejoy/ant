local ecs = ...
local world = ecs.world
local schema = world.schema

local crypt = require "crypt"

schema:type "serialize"
    .uuid "string"

local seria_comp = ecs.component_v2 "serialize"

function seria_comp:init()
    self.uuid = crypt.uuid()
    return self
end
