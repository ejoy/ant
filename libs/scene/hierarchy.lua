local ecs = ...

local hierarchy = require "hierarchy"

local h = ecs.component "hierarchy" {
    root = {type = "userdata", {}}
}

function h:init()
    self.root = hierarchy.new()
    self.name_mapper = {}    
end



