local ecs = ...
local world = ecs.world
local hierarchy_module = require "hierarchy"

local h = ecs.component "hierarchy" {
    --init from serialize or build from editable_hierarchy component in runtime
    builddata = {
        type = "userdata", 
        save = function(v, arg)
            assert(type(v) == "userdata")

            local t = {}
            for _, node in ipairs(v) do
                table.insert(t, node)
            end

            return t
        end,
        load = function(v, arg)
            assert(type(v) == "table")
            return hierarchy_module.build(v)
        end
    }  
}

function h:init()
    self.dirty = true
end

local n = ecs.component "hierarchy_name_mapper"{
    v = {
        type = "userdata", 
        save = function(v, arg)
            assert(type(v) == "table")
            local t = {}
            for k, eid in pairs(v) do
                assert(type(eid) == "number")
                local e = world[eid]
                local seri = e.serialize
                if seri then
                    t[k] = seri.uuid
                end
            end
            return t
        end,
        load = function(v, arg)
            assert(type(v) == "table")
            return v
        end
    }
}

function n:init()
    self.dirty = true
end