local luaecs = import_package "ant.luaecs"
local policy = require "policy"
local ecs = require "world"
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

local function getentityid(w)
    w._maxid = w._maxid + 1
    return w._maxid
end

local function create_entity_by_data(w, group, data)
    data.id = getentityid(w)
    data.group = group or 0
    w.w:new {
        create_entity = data
    }
    return data.id
end

local function create_entity_by_template(w, group, template)
    local data = {
        id = getentityid(w),
        group = group or 0,
    }
    local initargs = {
        data = data,
        template = template,
    }
    w.w:new {
        create_entity_template = initargs
    }
    return data.id, initargs
end

function world:_create_entity(package, group, v)
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
    return create_entity_by_data(self, group, data)
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end
local table_insert = table.insert

local function create_instance(w, group, prefab)
    local entities = {}
    local mounts = {}
    local noparent = {}
    for i = 1, #prefab do
        local v = prefab[i]
        local np
        if v.prefab then
            entities[i], np = create_instance(w, group, v.prefab)
        else
            local e, initargs = create_entity_by_template(w, group, v.template)
            entities[i], np = e, initargs
        end
        if v.mount then
            assert(
                math.type(v.mount) == "integer"
                and v.mount >= 1
                and v.mount <= #prefab
                and not prefab[v.mount].prefab
            )
            assert(v.mount < i)
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
                for _, m in ipairs(mounts[i]) do
                    m.parent = entities[v.mount]
                end
            else
                mounts[i].parent = entities[v.mount]
            end
        end
    end
    return entities, noparent
end

local function create_entity_template(w, v)
    local res = policy.create(w, nil, v.policy)
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
    return {
        action = v.action,
        mount = v.mount,
        template = w.w:template(data),
        tag = v.tag,
    }
end

local templates = {}

local create_template

local function create_template_(w, t)
	local prefab = {}
	for _, v in ipairs(t) do
        if not w.__EDITOR__ and v.editor then
            if v.prefab then
                v = {
                    prefab = "/pkg/ant.ecs/dummy.prefab"
                }
            else
                --TODO
                v = {
                    policy = {},
                    data = {},
                }
            end
        end
        if v.prefab then
            prefab[#prefab+1] = {
                prefab = create_template(w, v.prefab),
                args = v.args,
                mount = v.mount
            }
        else
            prefab[#prefab+1] = create_entity_template(w, v)
        end
    end
    return prefab
end

function create_template(w, filename)
    if type(filename) ~= "string" then
        return create_template_(w, filename)
    end
    if not templates[filename] then
        local t = serialize.parse(filename, cr.read_file(filename))
        templates[filename] = create_template_(w, t)
    end
    return templates[filename]
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

local function update_group_tag(w, data)
    local groupid = data.group
    for tag, t in pairs(w._group.tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

local function create_scene_entity(w, group)
    local eid = getentityid(w)
    local parent
    local data = {
        id = eid,
        group = group or 0,
        scene = {
            parent = parent,
        }
    }
    update_group_tag(w, data)
    w.w:new(data)
    w.w:group_update()
    w:call(eid, "init_scene")
    return eid
end

function world:create_object(inner_proxy)
    local w = self
    local on_init = inner_proxy.on_init
    local on_ready = inner_proxy.on_ready
    local on_update = inner_proxy.on_update
    local on_message = inner_proxy.on_message
    if not (on_init or on_ready or on_update or on_message) then
        return
    end
    local proxy_entity = {
        prefab = inner_proxy,
        animation_init = true
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
    local prefab = create_entity_by_data(w, inner_proxy.group, proxy_entity)

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
    function outer_proxy:remove()
        w:pub {"object_remove", prefab}
    end
    function inner_proxy:remove()
        w:pub {"object_remove", prefab}
    end

    local proxy = {}
    local proxy_mt = { __index = proxy, __newindex = proxy }
    setmetatable(outer_proxy, proxy_mt)
    setmetatable(inner_proxy, proxy_mt)
    return outer_proxy
end

function world:_create_instance(group, filename)
    local w = self
    local template = create_template(w, filename)
    local root = create_scene_entity(w, group)
    local prefab, noparent = create_instance(w, group, template)
    for _, m in ipairs(noparent) do
        m.parent = root
    end
    run_action(w, prefab, template)
    return {
        root = root,
        group = group,
        tag = create_tags(prefab, template)
    }
end

function world:detach_instance(instance)
    --Nothing to do
end

function world:_create_group(id)
    local w = self
    local group = w._group
    local mt = {}
    local api = {}
    mt.__index = api
    function api:create_entity(v)
        return w:_create_entity(package, id, v)
    end
    function api:create_instance(v)
        return w:_create_instance(id, v)
    end
    local function tags(tag)
        local t = group.tags[tag]
        if not t then
            t = {
                args = {},
            }
            group.tags[tag] = t
        end
        return t
    end
    function api:enable(tag)
        local t = tags(tag)
        if t[id] then
            return
        end
        group.dirty = true
        t.dirty = true
        t[id] = true
        table.insert(t.args, id)
    end
    function api:disable(tag)
        local t = tags(tag)
        if t[id] == nil then
            return
        end
        group.dirty = true
        t.dirty = true
        t[id] = nil
        for i = 1, #t.args do
            local v = t.args[i]
            if v == id then
                table.remove(t.args, i)
                break
            end
        end
    end
    return setmetatable({}, mt)
end

function world:_group_flush()
    local w = self
    local group = w._group
    if not group.dirty then
        return
    end
    group.dirty = nil
    local removed = {}
    for tag, t in pairs(group.tags) do
        if t.dirty then
            t.dirty = nil
            if #t.args == 0 then
                w.w:group_enable(tag)
                removed[tag] = true
            else
                w.w:group_enable(tag, table.unpack(t.args))
            end
        end
    end
    for tag in pairs(removed) do
        group.tags[tag] = nil
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
    local component_class =  self._class.component
    for name, info in pairs(self._decl.component) do
        local type = info.type[1]
        local class = component_class[name] or {}
        if type == "lua" then
            w:register {
                name = name,
                type = "lua",
                init = class.init,
                marshal = class.marshal or serialize.pack,
                unmarshal = class.unmarshal or serialize.unpack,
            }
        elseif type == "c" then
            local t = {
                name = name,
                init = class.init,
                marshal = class.marshal,
                unmarshal = class.unmarshal,
            }
            for i, v in ipairs(info.field) do
                t[i] = v
            end
            w:register(t)
        elseif type == nil then
            w:register {
                name = name
            }
        else
            w:register {
                name = name,
                type = type,
            }
        end
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
            table.insert(cfg.import, "@ant.ecs")
            cfg.system = cfg.system or {}
            table.insert(cfg.system, "ant.ecs|entity_system")
            table.insert(cfg.system, "ant.ecs|prefab_system")
            table.insert(cfg.system, "ant.ecs|debug_system")
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
