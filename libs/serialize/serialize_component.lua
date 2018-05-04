local ecs = ...

local crypt = require "crypt"

local seria_comp = ecs.component "serialize" {
    uuid = ""
}

function seria_comp:init()
    self.uuid = crypt.uuid()
end

local seri_tree = ecs.component "serialization_tree" {    
}

function seri_tree:init()
    self.root = {}
    self.name = ""

    self.luatext = true
    self.binary = true
end