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

local world_metatable = {}
local world = {}
world_metatable.__index = world

local function create_entity_by_data(w, group, data)
    local queue = w._create_entity_queue
    local eid = w.w:new {
        debug = debug.traceback()
    }
    local initargs = {
        eid = eid,
        group = group or 0,
        data = data,
    }
    queue[#queue+1] = initargs
    return eid
end

local function create_entity_by_template(w, group, template)
    local queue = w._create_entity_queue
    local eid = w.w:new {
        debug = debug.traceback()
    }
    local initargs = {
        eid = eid,
        group = group or 0,
        template = template,
    }
    queue[#queue+1] = initargs
    return eid, initargs
end

function world:create_entity(v, group)
    local policy_info = policy.create(self, v.policy)
    local data = v.data
    for c, def in pairs(policy_info.component_opt) do
        if data[c] == nil then
            data[c] = def
        end
    end
    for _, c in ipairs(policy_info.component) do
        local d = data[c]
        if d == nil then
            error(("component `%s` must exists"):format(c))
        end
    end
    return create_entity_by_data(self, group or 0, data)
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

local template_mt = {}

function template_mt:__gc()
    local destruct = self._world._destruct
    local template = self.template
    destruct[#destruct+1] = function (world)
        world.w:template_destruct(template)
    end
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

    return setmetatable({
        _world = w,
        mount = v.mount,
        template = w.w:template(data),
        tag = v.tag,
    }, template_mt)
end

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
                mount = v.mount
            }
        else
            prefab[#prefab+1] = create_entity_template(w, v)
        end
    end
    return prefab
end

function create_template(w, filename)
    local v = w._templates[filename]
    if not v then
        local realpath = assetmgr.compile(filename)
        local data = fastio.readall(realpath, filename)
        local t = serialize.parse(filename, data)
        v = create_template_(w, t)
        w._templates[filename] = v
    end
    return v
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

function world:_prefab_instance(group, parent, filename, tags)
    local w = self
    local template = create_template(w, filename)
    local prefab, noparent = create_instance(w, group, template)
    for _, m in ipairs(noparent) do
        m.parent = parent
    end
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

function world:create_instance(filename, parent, group)
    local q = self._create_prefab_queue
    local tags = {['*']={}}
    q[#q+1] = {
        group = group or 0,
        parent = parent,
        filename = filename,
        tags = tags,
    }
    return {
        group = group or 0,
        tag = tags
    }
end

function world:create_object(inner_proxy)
    local w = self
    local on_init = inner_proxy.on_init
    local on_ready = inner_proxy.on_ready
    local on_message = inner_proxy.on_message
    local proxy_entity = {
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
    local prefab = create_entity_by_data(w, inner_proxy.group, proxy_entity)
    local outer_proxy = {}
    if on_message then
        function outer_proxy:send(...)
            w:pub {"object_message", on_message, inner_proxy, ...}
        end
        function inner_proxy:send(...)
            w:pub {"object_message", on_message, inner_proxy, ...}
        end
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

function world:reset_prefab_cache(filename)
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

local function update_cpu_stat(w, funcs, symbols)
	local ecs_world = w._ecs_world
	local get_time = ltask.counter
	local MaxFrame <const> = 30
	local MaxText <const> = math.min(10, #funcs)
	local MaxName <const> = 48
	local CurFrame = 0
	local dbg_print = bgfx.dbg_text_print
	local printtext = {}
	local stat = {}
	for i = 1, #funcs do
		stat[i] = 0
	end
	for i = 1, MaxText do
		printtext[i] = ""
	end
	return function()
		for i = 1, #funcs do
			local f = funcs[i]
			local now = get_time()
			f(ecs_world)
			stat[i] = stat[i] + (get_time() - now)
		end
		if CurFrame ~= MaxFrame then
			CurFrame = CurFrame + 1
		else
			CurFrame = 1
			local t = {}
			for i = 1, #funcs do
				t[i] = {stat[i], i}
				stat[i] = 0
			end
			table.sort(t, function (a, b)
				return a[1] > b[1]
			end)
			for i = 1, MaxText do
				local m = t[i]
				local v, idx = m[1], m[2]
				local name = symbols[idx]
				printtext[i] = name .. (" "):rep(MaxName-#name) .. (" | %.02fms   "):format(v / MaxFrame * 1000)
			end
		end
		dbg_print(0, 2, 0x02, "--- system")
		for i = 1, MaxText do
			dbg_print(2, 2+i, 0x02, printtext[i])
		end
	end
end

local function update_math3d_stat(w, funcs, symbols)
	bgfx.enable_system_profile(false)

	local math3d = require "math3d"
	local ecs_world = w._ecs_world
	local MATH_INFO_TRANSIENT <const> = 2
	local MATH_INFO_MARKED <const> = 3
	local MATH_INFO_LAST <const> = 4
	local MATH_INFO_REF <const> = 6
	local MATH_INFO_SLOT <const> = 7
	local MaxFrame <const> = 30
	local MaxText <const> = math.min(10, #funcs)
	local MaxName <const> = 48
	local CurFrame = 0
	local dbg_print = bgfx.dbg_text_print
	local printtext = {}
	local transient_total = 0
	local marked_total = 0
	local ref_total = 0
	local slot_total = 0
	local transient_stat = {}
	for i = 1, #funcs do
		transient_stat[i] = 0
	end
	for i = 1, MaxText+4 do
		printtext[i] = ""
	end
	local components <const> = {
		"scene",
		"bounding",
		"mesh",
		"simplemesh",
		"meshskin",
		"daynight",
	}
	local ecs = w.w
	local function components_count()
		local s = {}
		for i = 1, #components do
			local name = components[i]
			if w._class.component[name] then
				s[#s+1] = ("%s:%d"):format(name, ecs:count(name))
			end
		end
		return table.concat(s, " ")
	end
	return function ()
		local last_transient = math3d.info(MATH_INFO_TRANSIENT)
		for i = 1, #funcs do
			local f = funcs[i]
			f(ecs_world)
			local transient = math3d.info(MATH_INFO_TRANSIENT)
			transient_stat[i] = math.max(transient_stat[i], (transient - last_transient))
			last_transient = transient
		end
		if CurFrame ~= MaxFrame then
			CurFrame = CurFrame + 1
		else
			CurFrame = 1
			local t = {}
			for i = 1, #funcs do
				t[i] = {transient_stat[i], i}
			end
			table.sort(t, function (a, b)
				return a[1] > b[1]
			end)
			local ref_frame = math3d.info(MATH_INFO_REF)
			if ref_total < ref_frame then
				ref_total = ref_frame
			end
			local marked_frame = math3d.info(MATH_INFO_MARKED) - ref_frame
			if marked_total < marked_frame then
				marked_total = marked_frame
			end
			local transient_frame = math3d.info(MATH_INFO_LAST)
			if transient_total < transient_frame then
				transient_total = transient_frame
			end
			local slot_frame = math3d.info(MATH_INFO_SLOT)
			if slot_total < slot_frame then
				slot_total = slot_frame
			end
			printtext[1] = "--- system"
			for i = 1, MaxText do
				local m = t[i]
				local transient, idx = m[1], m[2]
				local name = symbols[idx]
				printtext[i+1] = name .. (" "):rep(MaxName-#name) .. (" | %d  "):format(transient)
			end
			printtext[MaxText+2] = "--- total"
			printtext[MaxText+3] = ("transient:%d marked_slot:%d marked:%d ref:%d "):format(transient_total, slot_total, marked_total, ref_total)
			printtext[MaxText+4] = components_count()
		end
		for i = 1, #printtext do
			dbg_print(2, 1+i, 0x02, printtext[i])
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
	local MATH3D_STAT <const> = true
	if what == "_init" or what == "_update" then
		if CPU_STAT then
			return update_cpu_stat(w, funcs, symbols)
		elseif MATH3D_STAT then
			return update_math3d_stat(w, funcs, symbols)
		end
	end
	local ecs_world = w._ecs_world
	return function()
		for i = 1, #funcs do
			local f = funcs[i]
			f(ecs_world)
		end
	end
end

local function finish_memory_stat(ms)
	local start = ms.start
	local finish = ms.finish
	local res = ms.res
	ltask.mem_count(finish)
	for k, v in pairs(finish) do
		local diff = v - start[k]
		if diff > 0 then
			res[k] = (res[k] or 0) + diff
		end
	end
end

function world:memory_stat(what)
	local ms = self._memory_stat
	local res = self._memory[what]
	if not res then
		res = {}
		self._memory[what] = res
	end
	ms.res = res
	ltask.mem_count(ms.start)
	return ms
end

function world:pipeline_init()
	self.pipeline_entity_init = self:pipeline_func "_entity_init"
	self.pipeline_entity_remove = self:pipeline_func "_entity_remove"
	self.pipeline_update = self:pipeline_func "_update"
	self:pipeline_func "_init" ()
end

function world:pipeline_exit()
	self:pipeline_func "exit" ()
end

local function memstr(v)
	for _, b in ipairs {"B","KB","MB","GB","TB"} do
		if v < 1024 then
			return ("%.3f%s"):format(v, b)
		end
		v = v / 1024
	end
end

function world:memory(async)
	local function getmemory(module, getter)
		local m = require (module)
		return m[getter]()
		--TODO
		--if package.loaded[module] == nil then
		--	return
		--end
		--local m = package.loaded[module]
		--return m[getter]()
	end

	local m = {
		bgfx = getmemory("bgfx", "get_memory"),
		rp3d = getmemory("rp3d.core", "memory"),
		animation = getmemory("hierarchy", "memory"),
	}
	if require "bee.platform".os == "windows" then
		m.imgui = require "imgui".memory()
	end

	if async then
		local SERVICE_ROOT <const> = 1
		local services = ltask.call(SERVICE_ROOT, "label")
		local request = ltask.request()
		for id in pairs(services) do
			if id ~= 0 then
				request:add { id, proto = "system", "memory" }
			end
		end
		for req, resp in request:select() do
			if resp then
				local name = services[req[1]]
				local memory = resp[1]
				m["service-"..name] = memory
			end
		end
	else
		m.lua = collectgarbage "count" * 1024
	end

	local total = 0
	for k, v in pairs(m) do
		m[k] = memstr(v)
		total = total + v
	end
	m.total = memstr(total)
	return m
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

event.init(world)

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
    if config.DEBUG then
        luaecs.check_select(true)
    end
    local ecs = luaecs.world()
	local w; w = setmetatable({
		args = config,
		_memory = {},
		_memory_stat = setmetatable({start={}, finish={}}, {__close = finish_memory_stat}),
		_ecs = {},
		_group_tags = {},
		_create_entity_queue = {},
		_create_prefab_queue = {},
		_destruct = {},
		_clibs_loaded = {},
		_templates = {},
		w = ecs,
	}, world_metatable)

	-- load systems and components from modules
	typeclass.init(w, config)
	system.solve(w)

    for _, funcs in pairs(w._clibs_loaded) do
        for _, f in pairs(funcs) do
            debug.setupvalue(f, 1, w._ecs_world)
        end
    end
    return w
end

return m
