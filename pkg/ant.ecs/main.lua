local luaecs = import_package "ant.luaecs"
local serialize = import_package "ant.serialize"
local aio = import_package "ant.io"
local inputmgr = import_package "ant.inputmgr"
local ltask = require "ltask"
local bgfx = require "bgfx"
local policy = require "policy"
local event = require "event"
local feature = require "feature"
local cworld = require "cworld"
local components = require "ecs.components"

local world_metatable = {}
local world = {}
world_metatable.__index = world

local DEBUG <const> = luaecs.DEBUG

local function update_group_tag(w, groupid, data)
    for tag, t in pairs(w._group_tags) do
        if t[groupid] then
            data[tag] = true
        end
    end
end

function world:_flush_entity_queue()
    local queue = self._create_entity_queue
    if #queue == 0 then
        return
    end
    self._create_entity_queue = {}
    local ecs = self.w

    for i = 1, #queue do
        local initargs = queue[i]
        local eid = initargs.eid
        if not ecs:exist(eid) then
            log.warn(("entity `%d` has been removed."):format(eid))
            goto continue
        end
        local groupid = initargs.group
        local data = initargs.data
        local template = initargs.template
        data.INIT = true
        update_group_tag(self, groupid, data)
        if template then
            ecs:template_instance(eid, template, data)
        else
            ecs:import(eid, data)
        end
        ecs:group_add(groupid, eid)
        ::continue::
    end

    self._pipeline_entity_init()
    ecs:clear "INIT"
end

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
    local eid = create_entity_by_data(self, v.group or 0, v.data, debuginfo)
    return eid
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
    local noparent_eid = {}
    local noparent_data = {}
    for i = 1, #data do
        local v = data[i]
        local n_eid, n_data
        if v.prefab then
            entities[i], n_eid, n_data = create_instance(w, group, v.template, debuginfo)
        else
            local e, initargs = create_entity_by_template(w, group, v.template, v.has_scene, debuginfo)
            entities[i], n_eid, n_data = e, e, initargs
        end
        if v.mount then
            assert(
                math.type(v.mount) == "integer"
                and v.mount >= 1
                and v.mount <= #data
                and not data[v.mount].prefab
            )
            assert(v.mount < i)
            mounts[i] = n_data
        else
            if v.prefab then
                table_append(noparent_eid, n_eid)
                table_append(noparent_data, n_data)
            else
                table_insert(noparent_eid, n_eid)
                table_insert(noparent_data, n_data)
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
    return entities, noparent_eid, noparent_data
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
        local t = serialize.parse(filename, aio.readall(filename))
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

local function prefab_instance(w, v)
    if v.instance.REMOVED then
        return
    end
    local template = create_template(w, v.args.prefab)
    local prefab, noparent_eid, noparent_data = create_instance(w, v.args.group, template, v.debuginfo)
    v.instance.noparent = noparent_eid
    if v.args.parent then
        for _, m in ipairs(noparent_data) do
            if m.has_scene then
                m.data.scene_parent = v.args.parent
            end
        end
    end
    local tags = v.instance.tag
    each_prefab(prefab, template, function (eid, tag)
        if tag then
            if type(tag) == "table" then
                for _, tag_ in ipairs(tag) do
                    add_tag(tags, tag_, eid)
                end
            else
                add_tag(tags, tag, eid)
            end
        end
        table.insert(tags['*'], eid)
    end)
end

function world:_flush_instance_queue()
    local queue = self._create_prefab_queue
    if #queue == 0 then
        return
    end
    self._create_prefab_queue = {}
    for i = 1, #queue do
        prefab_instance(self, queue[i])
    end
end

function world:create_instance(args)
    local w = self
    args.group = args.group or 0
    local instance = {
        group = args.group,
        noparent = {},
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

function world:instance_set_parent(instance, parent)
    local w = self
    for _, eid in ipairs(instance.noparent) do
        local e <close> = w:entity(eid, "scene?update scene_needchange?out")
        assert(eid > parent)
        if e.scene then
            e.scene.parent = parent
            e.scene_needchange = true
        end
    end
end

function world:remove_instance(instance)
    assert(instance.tag)
    self:pub {"OnRemoveInstance", instance}
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

function world:set_mouse(e)
    self._mouse.x = e.x
    self._mouse.y = e.y
end

function world:get_mouse()
    return self._mouse
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

local function solve_depend(w, step, what, funcs, symbols)
	local pl = w._decl.pipeline[what]
	if not pl then
		return
	end
	for _, v in ipairs(pl) do
		local type, name = v[1], v[2]
		if type == "stage" then
			if step[name] == false then
				error(("pipeline has duplicate step `%s`"):format(name))
			elseif step[name] ~= nil then
				for _, s in ipairs(step[name]) do
					funcs[#funcs+1] = s.func
					symbols[#symbols+1] = s.symbol
				end
				--step[name] = false
			end
		elseif type == "pipeline" then
			solve_depend(w, step, name, funcs, symbols)
		end
	end
end

function world:pipeline_func(what, step)
    local w = self
    local funcs = {}
    local symbols = {}
    solve_depend(w, step or w._system_step, what, funcs, symbols)
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

local function emptyfunc(f)
	local info = debug.getinfo(f, "SL")
	if info.what ~= "C" then
		local lines = info.activelines
		if next(lines, next(lines)) == nil then
			return info
		end
	end
end

local function slove_system(systems)
	local system_step = {}
	for fullname, s in sortpairs(systems) do
		for step_name, func in pairs(s) do
			local symbol = fullname .. "." .. step_name
			local info = emptyfunc(func)
			if info then
				log.warn(("`%s` is an empty method, it has been ignored. (%s:%d)"):format(symbol, info.source:sub(2), info.linedefined))
			else
				local v = { func = func, symbol = symbol }
				local step = system_step[step_name]
				if step then
					step[#step+1] = v
				else
					system_step[step_name] = {v}
				end
			end
		end
	end
	return system_step
end

local function system_changed(w)
    if not w._system_changed then
        return
    end
    local initsystems = w._initsystems
    local exitsystems = w._exitsystems
    local has_initsystem = next(initsystems) ~= nil
    local has_exitsystem = next(exitsystems) ~= nil
    if not has_initsystem and not has_exitsystem then
        w._system_changed = nil
        return
    end
    log.info("System changed.")
    local updatesystems = w._updatesystems
    w._system_changed = nil
    w._initsystems = {}
    w._exitsystems = {}
    for name in pairs(exitsystems) do
        updatesystems[name] = nil
    end
    for name, s in pairs(initsystems) do
        updatesystems[name] = s
    end
    w._system_step = slove_system(updatesystems)
    w:pipeline_func "_pipeline" ()
    w._pipeline_entity_init = w:pipeline_func "_entity_init"
    w._pipeline_update = w:pipeline_func "_update"
    if has_exitsystem then
        for name in pairs(exitsystems) do
            updatesystems[name] = nil
        end
        local func = w:pipeline_func("_exit", slove_system(exitsystems))
        func()
    end
    if has_initsystem then
        for name, s in pairs(initsystems) do
            updatesystems[name] = s
        end
        initsystems["ant.ecs|entity_init_system"] = w._systems["ant.ecs|entity_init_system"]
        local step = slove_system(initsystems)
        w:pipeline_func("_init", step)()
    end
    log.info("System refreshed.")
end

function world:pipeline_init()
    system_changed(self)
end

function world:pipeline_update()
    local w = self
    system_changed(w)
    w._pipeline_update()
end

function world:pipeline_exit()
    local w = self
    w._system_changed = true
    w._exitsystems = w._systems
    w._initsystems = {}
    w._systems = {}
    system_changed(self)
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
    if w._ecs_world then
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

function world:import_feature(name)
    feature.import(self, { name })
end

function world:enable_system(name)
    local s = self._systems[name]
    if s then
        if not self._updatesystems[name] then
            self._initsystems[name] = s
            self._system_changed = true
        end
        self._exitsystems[name] = nil
    end
end

function world:disable_system(name)
    local s = self._systems[name]
    if s then
        if self._updatesystems[name] then
            self._exitsystems[name] = s
            self._system_changed = true
        end
        self._initsystems[name] = nil
    end
end

local m = {}

function m.new_world(config)
    do
        local cfg = config.ecs
        if cfg then
            cfg.feature = cfg.feature or {}
            table.insert(cfg.feature, 1, "ant.ecs")
        end
    end
    local ecs = luaecs.world(components)
    local w; w = setmetatable({
        args = config,
        _group_tags = {},
        _create_entity_queue = {},
        _create_prefab_queue = {},
        _destruct = {},
        _component_remove = {},
        _clibs_loaded = {},
        _templates = {},
        _cpu_stat = {},
        _envs = {},
        _packages = {},
        _components = {},
        _systems = {},
        _initsystems = {},
        _exitsystems = {},
        _updatesystems = {},
        _system_step = {},
        _system_changed = nil,
        _decl = {
            pipeline = {},
            component = {},
            feature = {},
            system = {},
            policy = {},
        },
        _newdecl = {
            component = {},
            system = {},
        },
        _mouse = { x = 0, y = 0 },
        w = ecs,
    }, world_metatable)

    event.init(w)
    inputmgr.init(w)

    log.info "world initializing"
    feature.import(w, config.ecs.feature)
    cworld.create(w)
    for _, funcs in pairs(w._clibs_loaded) do
        for _, f in pairs(funcs) do
            debug.setupvalue(f, 1, w._ecs_world)
        end
    end
    log.info "world initialized"
    return w
end

return m
