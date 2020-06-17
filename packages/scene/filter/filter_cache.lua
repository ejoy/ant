local ecs = ...
local world = ecs.world

local ic = ecs.interface "ifilter_cache"
function ic.check_add_cache(eid)
    local e = world[eid]
    if e._caches == nil then
        e._caches = {renderitems={}}
    end

    return e._caches.renderitems
end

function ic.cache(eid, what, value)
    world[eid]._caches.renderitems[what] = value
end

function ic.get(eid, what)
    local ri = world[eid]._caches.renderitems
    if ri then
        return ri[what]
    end
end