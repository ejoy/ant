local ecs = ...

local hierarchy = require "hierarchy"

local h = ecs.component "hierarchy" {
    builddata = {type = "userdata", {}}  --init from serialize or build from editable_hierarchy component in runtime
}

function h:init()
    self.dirty = true
end

local n = ecs.component "hierarchy_name_mapper"{
    v = {type="userdata", {}}
}

function n:init()
    self.dirty = true
end