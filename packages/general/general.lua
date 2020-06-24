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

local ct = ecs.transform "cache_transform"
function ct.process_prefab(e)
	e._cache_prefab = {}
end

local rct = ecs.transform "rendercache_transform"
function rct.process_entity(e)
    e._rendercache = {}
end

local m = ecs.action "name"
function m.init(prefab, i, value)
    prefab[value] = prefab[i]
end

local m = ecs.action "import"
function m.init(prefab, i, value)
    local name = value[1]
    local key = value[2]
    prefab[name] = assert(prefab[i])[key]
end
