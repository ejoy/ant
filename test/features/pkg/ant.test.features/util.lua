local ecs   = ...
local world = ecs.world
local w     = world.w

local util = {}

function util.create_instance(p, on_ready)
    return world:create_instance {
        prefab = p,
        on_ready = on_ready,
    }
end

function util.prefab_entities(p)
    local e = {}
    for _, eid in ipairs(p.tag['*']) do
        e[#e+1] = eid
    end
    return e
end

function util.remove_entities(e)
    for _, eid in ipairs(e) do
		world:remove_entity(eid)
	end
end

local PROXY_MT = {
    create_entity = function (self, ...)
        local eid = world:create_entity(...)
        self._entities[#self._entities+1] = eid
        return eid
    end,
    create_prefab = function (self, p)
        local old_on_ready = p.on_ready
        p.on_ready = function (pp)
            old_on_ready(pp)
            self:add_prefab(pp)
        end
        return world:create_prefab(p)
    end,
    add_prefab = function (self, p)
        local e = util.prefab_entities(p)
        table.move(e, 1, #e, #self._entities+1, self._entities)
        return p
    end,
    add_entity = function (self, eid)
        self._entities[#self._entities+1] = eid
    end,
    clear = function (self)
        util.remove_entities(self._entities)
        self._entities = {}
    end
}

function util.proxy_creator()
    return setmetatable({_entities={}}, {__index=PROXY_MT})
end

return util