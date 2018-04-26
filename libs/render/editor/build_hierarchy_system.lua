local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"

local build_system = ecs.system "build_hierarchy_system"

function build_system:update()
    for _, eid in world:each("editable_hierarchy") do
        local e = world[eid]
        if e.hierarchy == nil then
            world:add_component(eid, "hierarchy")
        end

        local editable_hierarchy = e.editable_hierarchy
        local hierarchy = e.hierarchy

        if editable_hierarchy.dirty then
            hierarchy.builddata = hierarchy_module.build(editable_hierarchy.root)
            hierarchy.dirty = true
            editable_hierarchy.dirty = false
        end
    end
end