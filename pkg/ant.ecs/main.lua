local luaecs = import_package "ant.luaecs"
local assetmgr = import_package "ant.asset"
local serialize = import_package "ant.serialize"
local ltask = require "ltask"
local bgfx = require "bgfx"
local fastio = require "fastio"
local policy = require "policy"
local typeclass = require "typeclass"
local system = require "system"
local event = require "event"
local vfs = require "vfs"
local pm = require "packagemanager"

local world_metatable = {}
local world = {}
world_metatable.__index = world

local DEBUG <const> = luaecs.DEBUG

local function create_entity_by_data(w, group, data, debuginfo)
    local queue = w._create_entity_queue
    local eid = w.w:new {
        debug = debuginfo
    }
    local initargs = {
        eid = eid,
        group = group,
        data = data,
    }
    queue[#queue+1] = initargs
    return eid
end

local function create_entity_by_template(w, group, template, has_scene, debuginfo)
    local queue = w._create_entity_queue
    local eid = w.w:new {
        debug = debuginfo,
    }
    local initargs = {
        eid = eid,
        group = group,
        template = template,
        has_scene = has_scene,
        data = {},
    }
    queue[#queue+1] = initargs
    return eid, initargs
end

function world:create_entity(v)
    policy.verify(self, v.policy, v.data)
    local debuginfo
    if DEBUG then
        debuginfo = debug.traceback()
    end
    return create_entity_by_data(self, v.group or 0, v.data, debuginfo)
end

function world:remove_entity(e)
    local w = self
    w.w:remove(e)
end

local function table_append(t, a)
    table.move(a, 1, #a, #t+1, t)
end
local table_insert = table.insert

local function create_instance(w, group, data, debuginfo)
    local entities = {}
    local mounts = {}
    local noparent = {}
    for i = 1, #data do
        local v = data[i]
        local np
        if v.prefab then
            entities[i], np = create_instance(w, group, v.template, debuginfo)
        else
            local e, initargs = create_entity_by_template(w, group, v.template, v.has_scene, debuginfo)
            entities[i], np = e, initargs
        end
        if v.mount then
            assert(
                math.type(v.mount) == "integer"
                and v.mount >= 1
                and v.mount <= #data
                and not data[v.mount].prefab
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
    for i = 1, #data do
        local v = data[i]
        if v.mount then
            if v.prefab then
                for _, m in ipairs(mounts[i]) do
                    if m.has_scene then
                        m.data.scene_parent = entities[v.mount]
                    end
                end
            else
                assert(mounts[i].has_scene)
                mounts[i].data.scene_parent = entities[v.mount]
            end
        end
    end
    return entities, noparent
end

local template_mt = {}

function template_mt:__gc()
    local destruct = self._world._destruct
    local template = self.template
    destruct[#destruct+1] = function (world)
        world.w:template_destruct(template)
    end
end

local function create_entity_template(w, v)
    policy.verify(w, v.policy, v.data)
    return setmetatable({
        _world = w,
        mount = v.mount,
        template = w.w:template(v.data),
        tag = v.tag,
        has_scene = v.data.scene ~= nil,
    }, template_mt)
end

local function create_template(w, filename)
    local prefab = w._templates[filename]
    if not prefab then
        prefab = {}
        w._templates[filename] = prefab
        local realpath = assetmgr.compile(filename)
        local data = fastio.readall(realpath, filename)
        local t = serialize.parse(filename, data)
        for _, v in ipairs(t) do
            if v.prefab then
                prefab[#prefab+1] = {
                    prefab = v.prefab,
                    mount = v.mount,
                    template = create_template(w, v.prefab),
                }
            else
                prefab[#prefab+1] = create_entity_template(w, v)
            end
        end
    end
    return prefab
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
            each_prefab(entities[i], e.template, f)
        else
            f(entities[i], e.tag)
        end
    end
end

function world:_prefab_instance(v)
    local w = self
    local template = create_template(w, v.args.prefab)
    local prefab, noparent = create_instance(w, v.args.group, template, v.debuginfo)
    for _, m in ipairs(noparent) do
        if m.has_scene then
            m.data.scene_parent = v.args.parent
        end
    end
    local tags = v.instance.tag
    each_prefab(prefab, template, function (e, tag)
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
end

function world:create_instance(args)
    local w = self
    args.group = args.group or 0
    local instance = {
        group = args.group,
        tag = {['*']={}}
    }
    local debuginfo
    if DEBUG then
        debuginfo = debug.traceback(args.prefab)
    end
    local q = self._create_prefab_queue
    q[#q+1] = {
        instance = instance,
        args = args,
        debuginfo = debuginfo,
    }
    local on_ready = args.on_ready
    local on_message = args.on_message
    local proxy_entity = {}
    if on_ready then
        function proxy_entity.on_ready()
            on_ready(instance)
        end
    end
    if on_message then
        function proxy_entity.on_message(_, ...)
            on_message(instance, ...)
        end
    end
    if next(proxy_entity) then
        instance.proxy = create_entity_by_data(w, args.group, proxy_entity, debuginfo)
    end
    return instance
end

function world:remove_instance(instance)
    assert(instance.tag)
    world:pub {"OnRemoveInstance1", instance}
end

function world:remove_template(filename)
    self._templates[filename] = nil
end

function world:group_enable_tag(tag, id)
    local w = self
    local t = w._group_tags[tag]
    if not t then
        t = {
            args = {},
        }
        w._group_tags[tag] = t
    end
    if t[id] then
        return
    end
    t.dirty = true
    t[id] = true
    table.insert(t.args, id)
end

function world:group_disable_tag(tag, id)
    local w = self
    local t = w._group_tags[tag]
    if not t then
        return
    end
    if t[id] == nil then
        return
    end
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

function world:group_flush(tag)
    local w = self
    local group_tags = w._group_tags
    local t = group_tags[tag]
    if not t.dirty then
        return
    end
    t.dirty = nil
    if #t.args == 0 then
        w.w:group_enable(tag)
        group_tags[tag] = nil
    else
        w.w:group_enable(tag, table.unpack(t.args))
    end
end

local function cpustat_update(w, funcs, symbols)
    local ecs_world = w._ecs_world
    local get_time = ltask.counter
    return function()
        local stat = w._cpu_stat
        for i = 1, #funcs do
            local f = funcs[i]
            local now = get_time()
            f(ecs_world)
            local time = get_time() - now
            local name = symbols[i]
            if stat[name] then
                stat[name] = stat[name] + time
            else
                stat[name] = time
                stat[#stat+1] = name
            end
        end
    end
end

local function cpustat_update_then_print(w, funcs, symbols)
    local update_func = cpustat_update(w, funcs, symbols)
    local MaxFrame <const> = 30
    local MaxText <const> = math.min(10, #funcs)
    local MaxName <const> = 48
    local CurFrame = 0
    local dbg_print = bgfx.dbg_text_print
    local printtext = {}
    for i = 1, MaxText do
        printtext[i] = ""
    end
    return function()
        update_func()
        if CurFrame ~= MaxFrame then
            CurFrame = CurFrame + 1
        else
            CurFrame = 1
            local stat = w._cpu_stat
            table.sort(stat, function (a, b)
                return stat[a] > stat[b]
            end)
            for i = 1, MaxText do
                local name = stat[i]
                local v = stat[name]
                printtext[i] = name .. (" "):rep(MaxName-#name) .. (" | %.02fms   "):format(v / MaxFrame * 1000)
            end
            w._cpu_stat = {}
        end
        dbg_print(0, 2, 0x02, "--- system")
        for i = 1, MaxText do
            dbg_print(2, 2+i, 0x02, printtext[i])
        end
    end
end

function world:pipeline_func(what)
    local w = self
    local funcs, symbols = system.lists(w, what)
    if not funcs or #funcs == 0 then
        return function() end
    end
    local CPU_STAT <const> = true
    if CPU_STAT then
        if what == "_update" then
            return cpustat_update_then_print(w, funcs, symbols)
        end
        return cpustat_update(w, funcs, symbols)
    end
    local ecs_world = w._ecs_world
    return function()
        for i = 1, #funcs do
            local f = funcs[i]
            f(ecs_world)
        end
    end
end

function world:pipeline_init()
    self.pipeline_update = self:pipeline_func "_update"
    self:pipeline_func "_init" ()
end

function world:pipeline_exit()
    self:pipeline_func "_exit" ()
end

function world:clibs(name)
    local w = self
    local loaded = w._clibs_loaded
    if loaded[name] then
        return loaded[name]
    end
    local initfunc = assert(package.preload[name])
    local funcs = initfunc()
    loaded[name] = funcs
    if not w._initializing then
        for _, f in pairs(funcs) do
            debug.setupvalue(f, 1, w._ecs_world)
        end
    end
    return funcs
end

local submit = setmetatable({}, {__mode="k", __index = function (t, w)
    local mt = {}
    function mt:__close()
        w:submit(self)
    end
    t[w] = mt
    return mt
end})

function world:entity(eid, pattern)
    local v = self.w:fetch(eid, pattern)
    if v then
        return setmetatable(v, submit[self.w])
    end
end

function world:entity_message(eid, ...)
    self:pub {"EntityMessage", eid, ...}
end

function world:instance_message(instance, ...)
    self:pub {"EntityMessage", instance.proxy, ...}
end

function world:_package_require(package, file)
    local w = self
    local _PACKAGE = w._packages[package]
    local _LOADED = _PACKAGE._LOADED
    local p = _LOADED[file]
    if p ~= nil then
        return p
    end
    local env = pm.loadenv(package)
    local path = "/pkg/"..package.."/"..file
    local realpath = vfs.realpath(path)
    if not realpath then
        error(("file '%s' not found"):format(path))
    end
    local initfunc, err = fastio.loadfile(realpath, path, env)
    if not initfunc then
        error(("error loading file '%s':\n\t%s"):format(path, err))
    end
    debug.setupvalue(initfunc, 1, env)
    local r = initfunc(_PACKAGE.ecs)
    if r == nil then
        r = true
    end
    _LOADED[file] = r
    return r
end

event.init(world)

local m = {}

function m.new_world(config)
    do
        local cfg = config.ecs
        if cfg then
            cfg.feature = cfg.feature or {}
            table.insert(cfg.feature, 1, "ant.ecs")
        end
    end
    local ecs = luaecs.world()
    local w; w = setmetatable({
        args = config,
        _group_tags = {},
        _create_entity_queue = {},
        _create_prefab_queue = {},
        _destruct = {},
        _clibs_loaded = {},
        _templates = {},
        _packages = {},
        _cpu_stat = {},
        w = ecs,
    }, world_metatable)

    -- load systems and components from modules
    typeclass.init(w, config)

    for _, funcs in pairs(w._clibs_loaded) do
        for _, f in pairs(funcs) do
            debug.setupvalue(f, 1, w._ecs_world)
        end
    end
    return w
end

return m
