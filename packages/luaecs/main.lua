local luaecs = require "ecs"
local policy = require "policy"
local ecs = import_package "ant.ecs"
local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

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

function world:_create_entity(package, v)
    local res = policy.create(self, package, v.policy)
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

function world:create_entity(v)
    log.error("world:create_entity is deprecated, use ecs.create_entity instead.")
    return self:_create_entity(nil, v)
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end
local table_insert = table.insert

local function create_instance(w, prefab)
    local entities = {}
    local mounts = {}
    local noparent = {}
    for i = 1, #prefab do
        local v = prefab[i]
        local np
        if v.prefab then
            entities[i], np = create_instance(w, v.prefab)
        else
            local e = create_entity(w, v.template)
            entities[i], np = e, e
        end
        if v.mount then
            assert(
                math.type(v.mount) == "integer"
                and v.mount >= 1
                and v.mount <= #prefab
                and not prefab[v.mount].prefab
            )
            mounts[i] = np
        else
            if v.prefab then
                table_append(noparent, np)
            else
                table_insert(noparent, np)
            end
        end
    end
    for i = 1, #prefab do
        local v = prefab[i]
        if v.mount then
            if v.prefab then
                w:multicast(mounts[i], "set_parent", entities[v.mount])
            else
                w:call(mounts[i], "set_parent", entities[v.mount])
            end
        end
    end
    return entities, noparent
end

local function create_entity_template(w, package, detach, v)
    local res = policy.create(w, package, v.policy)
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
        mount = v.mount,
        template = data,
        tag = v.tag,
    }
end

local function create_template(w, package, detach, filename)
    local t = filename
    if type(filename) ~= "table" then
        t = serialize.parse(filename, cr.read_file(filename))
    end
	local prefab = {}
	for _, v in ipairs(t) do
		if v.prefab then
			prefab[#prefab+1] = {
                prefab = create_template(w, package, detach, v.prefab),
				args = v.args,
			}
		else
			prefab[#prefab+1] = create_entity_template(w, package, detach, v)
		end
	end
    return prefab
end

local function run_action(w, entities, template)
    for i, entity in ipairs(template) do
        if entity.prefab then
            run_action(w, entities[i], entity.prefab)
        elseif entity.action then
            for name, target in sortpairs(entity.action) do
                if target:match "@(%d*)" then
                    target = entities[tonumber(target:sub(2))]
                end
                w:call(entities[i], name, target)
            end
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

local function create_scene_entity(w)
    local e = {}
    w.w:new {
        reference = e,
        scene = {
            srt = {},
        }
    }
    w:call(e, "init_scene")
    return e
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
        function proxy_entity.on_init()
            on_init(inner_proxy)
        end
    end
    if on_ready then
        function proxy_entity.on_ready()
            on_ready(inner_proxy)
        end
    end
    if on_update then
        function proxy_entity.on_update()
            on_update(inner_proxy)
        end
    end
    local prefab = create_entity(w, proxy_entity)

    if not on_update and not on_message then
        w:pub {"object_detach", prefab}
        return
    end

    local outer_proxy = {root = inner_proxy.root}
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

function world:_create_instance(package, filename, options)
    local w = self
    local detach = options and options.detach
    local template = create_template(w, package, detach, filename)
    local root = create_scene_entity(w)
    local prefab, noparent = create_instance(w, template)
    w:multicast(noparent, "set_parent", root)
    run_action(w, prefab, template)
    return {
        root = root,
        tag = create_tags(prefab, template)
    }
end

function world:create_instance(filename, options)
    log.error("world:create_instance is deprecated, use ecs.create_instance instead.")
    return self:_create_instance(nil, filename, options)
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
        if cfg then
            cfg.pipeline = {
                "_init", "_update", "exit"
            }
            cfg.import = cfg.import or {}
            table.insert(cfg.import, "@ant.luaecs")
            cfg.system = cfg.system or {}
            table.insert(cfg.system, "ant.luaecs|entity_system")
            table.insert(cfg.system, "ant.luaecs|prefab_system")
            table.insert(cfg.system, "ant.luaecs|debug_system")
        end
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
