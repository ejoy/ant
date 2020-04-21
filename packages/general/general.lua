local ecs = ...
local assetmgr = import_package "ant.asset"

ecs.component_alias("name", "string", "")

local m = ecs.component_alias("resource", "string")

function m:init()
    return assetmgr.load(self, nil, true)
end

function m:save()
    --TODO
end

local m = ecs.component_alias("multiple_resource", "string[]")

function m:init()
    if type(self) ~= "table" then
        return assetmgr.load_multiple({self}, {}, true)
    else
        return assetmgr.load_multiple(self, {}, true)
    end
end

function m:save()
    --TODO
end
