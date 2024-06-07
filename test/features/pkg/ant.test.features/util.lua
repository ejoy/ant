local ecs   = ...
local world = ecs.world
local w     = world.w

local util = {}

function util.create_shadow_plane(sx, sz)
    sz = sz or sx
    return world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {s = {sx, 1, sz},},
			mesh        = "plane.primitive",
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible     = true,
		}
	}
end

function util.create_instance(p, on_ready)
    return world:create_instance {
        prefab = p,
        on_ready = on_ready,
    }
end

function util.remove_entities(e)
    for _, eid in ipairs(e) do
		world:remove_entity(eid)
	end
end

local PROXY_MT = {
    create_entity = function (self, ...)
        return self:add_entity(world:create_entity(...))
    end,
    create_instance = function (self, ...)
        return self:add_instance(world:create_instance(...))
    end,
    add_instance = function (self, p)
        self._instances[#self._instances+1] = p
        return p
    end,
    add_entity = function (self, eid)
        self._entities[#self._entities+1] = eid
        return eid
    end,
    clear = function (self)
        util.remove_entities(self._entities)
        self._entities = {}

        for _, p in ipairs(self._instances) do
            world:remove_instance(p)
        end
        self._instances = {}
    end
}

function util.proxy_creator()
    return setmetatable({_entities={}, _instances={}}, {__index=PROXY_MT})
end

return util