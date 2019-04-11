local ecs = ...

ecs.import "ant.math"
ecs.import "ant.render"

local world = ecs.world

local main = ecs.system "system1"
function main:init(...)
    local a = {...}
    print "herllo init"
    local id = world:new_entity ("vector","int")
    local ent = world[id]
    print(">>>>>>>>>>ent:")
    print_a(ent)
    print(">>>>>>>>frustum:")
    print_a(world.schema.map.frustum)
end
local count = 0
local os = require "os"
function main:update(...)
    local a = {...}
    count = count + 1
        -- print("update",count,os.clock())
end


