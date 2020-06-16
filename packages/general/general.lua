local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"

local m = ecs.component "resource"

function m:init()
    return assetmgr.resource(world, self)
end

function m:save()
    return tostring(self):match "^(.-):?$"
end
