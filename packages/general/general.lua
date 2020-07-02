local ecs = ...

local math3d = require "math3d"

local ct = ecs.transform "cache_transform"
function ct.process_prefab(e)
	e._cache_prefab = {}
end

local rct = ecs.transform "rendercache_transform"
function rct.process_entity(e)
    e._rendercache = {}
end

local gt = ecs.transform "init_transform"

function gt.process_entity(e)
	e._rendercache.srt			= math3d.ref(math3d.matrix(e.transform))
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
