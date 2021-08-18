local luaecs = require "ecs"
local policy = require "policy"
local ecs = import_package "ant.ecs"
local assetmgr = import_package "ant.asset"

local world = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

function world:pipeline_init()
    self:pipeline_func "_init" ()
    self._update_func = self:pipeline_func "_update"
end

local function create_entity(w, data)
    if not data.reference then
        w.w:new {
            create_entity = data
        }
        return
    end
    local ref = {}
    data.reference = ref
    w.w:new {
        create_entity = data
    }
    return ref
end

function world:create_entity(v)
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
    return create_entity(self, data)
end

function world:create_ref(v)
    local mainkey = policy.find_mainkey(self, v)
    return self.w:ref(mainkey, v)
end

local function instance(w, prefab)
	local res = {}
    local _ = prefab[1]
	for k, v in pairs(prefab) do
		if v.prefab then
			res[k] = instance(w, v.prefab)
		else
			res[k] = create_entity(w, v.template)
		end
	end
	return res
end

local function create_entity_template(w, v)
    local res = policy.create(w, v.policy)
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
    data.reference = true
    return {
        action = v.action,
        template = data,
        tag = v.tag,
    }
end

local function create_template(w, t)
	local prefab = {}
	for _, v in ipairs(t) do
		if v.prefab then
			prefab[#prefab+1] = {
                prefab = assetmgr.resource(v[1], { create_template = function (_,...) return create_template(w,...) end }),
				args = v.args,
			}
		else
			prefab[#prefab+1] = create_entity_template(w, v)
		end
	end
    return prefab
end

local function run_action(w, res, prefab)
	for i, entity in ipairs(prefab) do
		if entity.action then
			for name, target in sortpairs(entity.action) do
				local object = w._class.action[name]
				assert(object and object.init)
				object.init(res, i, target)
			end
		end
	end
	for i, v in ipairs(prefab) do
		if v.prefab then
			if v.args then
				for k, v in pairs(v.args) do
					res[i][k] = res[v]
				end
			end
			run_action(w, res[i], v.prefab)
		end
	end
end

local function add_tag(dict, tag, eid)
	if dict[tag] then
		table.insert(dict[tag], eid)
	else
		dict[tag] = {eid}
	end
end

local function each_prefab(entities, template, f)
    for i, e in ipairs(template) do
        if e.prefab then
            each_prefab(entities[i], e.prefab, f)
        else
            f(entities[i], template.tag)
        end
    end
end

local function create_tagdict(entities, template)
    local dict = {['*']={}}
    each_prefab(entities, template, function (e, tag)
        if tag then
            if type(tag) == "table" then
                for _, tag_ in ipairs(tag) do
                    add_tag(dict, tag_, e)
                end
            else
                add_tag(dict, tag, e)
            end
        end
        table.insert(dict['*'], e)
    end)
    return dict
end

local function create_proxy(w, event, entities, template)
    local init = event.init
    local update = event.update
    local message = event.message
    if not init and not update and not message then
        return
    end

    local dict = create_tagdict(entities, template)
    local inner_proxy = {}
    local proxy_entity = {
        reference = true,
        prefab = {entities=dict['*']},
    }
    function inner_proxy:tag(tag)
        return dict[tag]
    end
    if init then
        function proxy_entity.prefab_init()
            init(inner_proxy)
        end
    end
    if update then
        function proxy_entity.prefab_update()
            update(inner_proxy)
        end
    end
    local prefab = create_entity(w, proxy_entity)

    if not update and not message then
        w:pub {"object_detach", prefab}
        return
    end

    local outer_proxy = {}
    function outer_proxy:root()
    end
    if message then
        function outer_proxy:message(...)
            w:pub {"object_message", message, inner_proxy, ...}
        end
        function inner_proxy:message(...)
            w:pub {"object_message", message, inner_proxy, ...}
        end
    end
    function outer_proxy:detach()
        w:pub {"object_detach", prefab}
    end
    function inner_proxy:detach()
        w:pub {"object_detach", prefab}
    end

    local proxy = {}
    local proxy_mt = { __index = proxy, __newindex = proxy }
    setmetatable(outer_proxy, proxy_mt)
    setmetatable(inner_proxy, proxy_mt)
    return outer_proxy
end

function world:create_object(e)
    local w = self
    local template = assetmgr.resource(e[1], { create_template = function (_,...) return create_template(w,...) end })
    local entities = instance(w, template)
    run_action(w, entities, template)
    return create_proxy(w, e, entities, template)
end

function world:command(entity, ...)
    self:pub {"entity_command", entity, ...}
end

function world:command_broadcast(set, ...)
    for i = 1, #set do
        self:pub {"entity_command", set[i], ...}
    end
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
		table.insert(cfg.system, "ant.luaecs|prefab_system")
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
