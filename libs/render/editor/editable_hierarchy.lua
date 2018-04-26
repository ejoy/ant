local ecs = ...

local hierarchy = require "hierarchy"

local eh = ecs.component "editable_hierarchy"{
    root = {type = "userdata", 
    default = function() 
        return hierarchy.new() 
    end}
}

function eh:init()
    self.dirty = true
end

