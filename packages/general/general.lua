local ecs = ...

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local rct = ecs.transform "rendercache_transform"
function rct.process_entity(e)
    e._rendercache = {}
end

local gt = ecs.transform "init_transform"

function gt.process_entity(e)
    e._rendercache.srt = mu.srt_obj(e.transform or {})
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
