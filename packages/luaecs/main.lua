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

local function create_instance(w, prefab)
	local res = {}
    local _ = prefab[1]
	for k, v in pairs(prefab) do
		if v.prefab then
			res[k] = create_instance(w, v.prefab)
		else
			res[k] = create_entity(w, v.template)
		end
	end
	return res
end

local function create_entity_template(w, detach, v)
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
    data.reference = detach == nil
    return {
        action = v.action,
        template = data,
        tag = v.tag,
    }
end

local function create_template(w, detach, t)
	local prefab = {}
	for _, v in ipairs(t) do
		if v.prefab then
			prefab[#prefab+1] = {
                prefab = assetmgr.resource(v[1], { create_template = function (_,...) return create_template(w,detach,...) end }),
				args = v.args,
			}
		else
			prefab[#prefab+1] = create_entity_template(w, detach, v)
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
            f(entities[i], e.tag)
        end
    end
end

local function create_tags(entities, template)
    local tags = {['*']={}}
    each_prefab(entities, template, function (e, tag)
        if tag then
            if type(tag) == "table" then
                for _, tag_ in ipairs(tag) do
                    add_tag(tags, tag_, e)
                end
            else
                add_tag(tags, tag, e)
            end
        end
        table.insert(tags['*'], e)
    end)
    return tags
end

function world:create_object(inner_proxy)
    local w = self
    local on_init = inner_proxy.on_init
    local on_ready = inner_proxy.on_ready
    local on_update = inner_proxy.on_update
    local on_message = inner_proxy.on_message
    if not on_init and not on_update and not on_message then
        return
    end
    local proxy_entity = {
        reference = true,
        prefab = inner_proxy,
    }
    if on_init then
        function proxy_entity.prefab_init()
            on_init(inner_proxy)
        end
    end
    if on_ready then
        function proxy_entity.prefab_ready()
            on_ready(inner_proxy)
        end
    end
    if on_update then
        function proxy_entity.prefab_update()
            on_update(inner_proxy)
        end
    end
    local prefab = create_entity(w, proxy_entity)

    if not on_update and not on_message then
        w:pub {"object_detach", prefab}
        return
    end

    local outer_proxy = {}
    if on_message then
        function outer_proxy:send(...)
            w:pub {"object_message", on_message, inner_proxy, ...}
        end
        function inner_proxy:send(...)
            w:pub {"object_message", on_message, inner_proxy, ...}
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

function world:create_instance(filename, detach)
    local w = self
    local template = assetmgr.resource(filename, { create_template = function (_,...) return create_template(w, detach, ...) end })
    local entities = create_instance(w, template)
    run_action(w, entities, template)
    return {
        tag = create_tags(entities, template)
    }
end

local function isValidReference(reference)
    return reference[1] ~= nil
end

function world:detach_instance(instance)
    local w = self.w
    for _, entity in ipairs(instance.tag["*"]) do
        if isValidReference(entity) then
            w:remove_reference(entity)
        end
    end
end

function world:call(e, name, ...)
    local f = self._methods[name]
    if not f then
        error(("Method `%s` is not defined."):format(name))
    end
    return f(e, ...)
end

function world:multicall(set, name, ...)
    local f = self._methods[name]
    if not f then
        error(("Method `%s` is not defined."):format(name))
    end
    local res = {}
    for i = 1, #set do
        res[i] = f(set[i], ...)
    end
    return res
end

function world:multicast(set, name, ...)
    local f = self._methods[name]
    if not f then
        error(("Method `%s` is not defined."):format(name))
    end
    for i = 1, #set do
        f(set[i], ...)
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
        if type == "order" then
            w:register {
                name = name,
                order = true
            }
        elseif type == "ref" then
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
