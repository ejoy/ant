local luaecs = require "ecs"
local policy = require "policy"
local ecs = import_package "ant.ecs"

local world = {}

function world:pipeline_init()
    self:pipeline_func "_init" ()
    self._update_func = self:pipeline_func "_update"
end

function world:luaecs_create_entity(v)
    local res = policy.create(self, v.policy)
    local data = v.data
    for c, def in pairs(res.component_opt) do
        if data[c] == nil then
            data[c] = def
        end
    end
    for _, c in ipairs(res.component) do
        local d = data[c]
        if d == nil then
            error(("component `%s` must exists"):format(c))
        end
    end
    if not data.reference then
        self.w:new {
            create_entity = data
        }
        return
    end
    local ref = {}
    data.reference = ref
    self.w:new {
        create_entity = data
    }
    return ref
end

function world:luaecs_create_ref(v)
    local mainkey = policy.find_mainkey(self, v)
    return self.w:ref(mainkey, v)
end

local function update_decl(self)
    local w = self.w
    local decl = self._decl
    local component = decl.component_v2
    for name, info in pairs(component) do
        if name == "reference" then
            goto continue
        end
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
        ::continue::
    end
end

local m = {}

function m.new_world(config)
	do
		local cfg = config.ecs
		cfg.pipeline = {
			"_init", "_update", "exit"
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
