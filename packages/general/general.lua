local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"

ecs.component_alias("name", "string", "")

local m = ecs.component_alias("resource", "string")

function m:init()
    return assetmgr.resource(world, self)
end

function m:save()
    return tostring(self):match "[^:]+"
end

ecs.component_alias("entityid", "int")
