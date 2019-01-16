local ecs = ...

local crypt = require "crypt"

local seria_comp = ecs.component_struct "serialize" {
    uuid = "",
}

function seria_comp:init()
    self.uuid = crypt.uuid()
end
