local luaecs = require "ecs"
local policy = require "policy"
local ecs = import_package "ant.ecs"

local world = {}

function world:pipeline_init()
    self:pipeline_func "init" ()
    self._update_func = self:pipeline_func "_update"
end

function world:luaecs_create_entity(v)
    local res = policy.create(self, v.policy)
    for _, c in ipairs(res.component) do
        local d = v.data[c]
        if d == nil then
            error(("component `%s` must exists"):format(c))
        end
    end
    self.w:new {
        create_entity = v.data
    }
end

function world:luaecs_create_ref(v)
    local res = policy.create_ref(self, v.policy)
    for _, c in ipairs(res.component) do
        local d = v.data[c]
        if d == nil then
            error(("component `%s` must exists"):format(c))
        end
    end
    return self.w:ref(res.mainkey, v.data)
end

local function update_decl(self)
    local w = self.w
    local decl = self._decl
    local component = decl.component_v2
    for name, info in pairs(component) do
        local type = info.type[1]
        if type == "ref" then
            w:register {
                name = name,
                type = "lua",
                ref = true
            }
        else
            w:register {
                name = name,
                type = type
            }
        end
    end
end

local m = {}

function m.new_world(config)
	do
		local cfg = config.ecs
		cfg.pipeline = {
			"init", "_update", "exit"
		}
		cfg.import = cfg.import or {}
		table.insert(cfg.import, "@ant.luaecs")
		cfg.system = cfg.system or {}
		table.insert(cfg.system, "ant.luaecs|entity_system")
	end
    config.w = luaecs.world()
    config.update_decl = update_decl
    local res = ecs.new_world(config)
    for k, v in pairs(world) do
        res[k] = v
    end
    return res
end

return m
