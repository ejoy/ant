local ecs = ...

local crypt = require "crypt"

local seria_comp = ecs.component "serialize" {
    uuid = ""
}

function seria_comp:init()
    self.uuid = crypt.uuid()
end

local seri_tree = ecs.component "serialize_tree" {    
}

function seri_tree:init()
    self.root = {}
end