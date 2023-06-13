local typeclass = require "typeclass"
local system = require "system"
local event = require "event"
local ltask = require "ltask"
local bgfx = require "bgfx"

local world = {}
world.__index = world

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
	local math3d = require "math3d"
	local ecs_world = w._ecs_world
	local MATH_INFO_TRANSIENT <const> = 2
	local MaxFrame <const> = 30
	local MaxText <const> = math.min(9, #funcs)
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
	return function ()
		local last = math3d.info(MATH_INFO_TRANSIENT)
		for i = 1, #funcs do
			local f = funcs[i]
			f(ecs_world)
			local transient = math3d.info(MATH_INFO_TRANSIENT)
			stat[i] = math.max(stat[i], (transient - last))
			last = transient
		end
		if CurFrame ~= MaxFrame then
			CurFrame = CurFrame + 1
		else
			CurFrame = 1
			local total = 0
			local t = {}
			for i = 1, #funcs do
				t[i] = {stat[i], i}
				total = total + stat[i]
			end
			table.sort(t, function (a, b)
				return a[1] > b[1]
			end)
			printtext[1] = "total" .. (" "):rep(MaxName-5) .. (" | %d   "):format(total)
			for i = 1, MaxText do
				local m = t[i]
				local v, idx = m[1], m[2]
				local name = symbols[idx]
				printtext[i+1] = name .. (" "):rep(MaxName-#name) .. (" | %d   "):format(v)
			end
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

function world:entity(eid)
	return self._entity[eid]
end

function world:debug_entity(eid)
	return self.w:readall(eid)
end

function world:clibs(name)
	local w = self
	local funcs = require(name)
	if w._initializing then
		local t = w._clibs
		if not t then
			t = {}
			w._clibs = t
		end
		t[#t+1] = name
	else
		for _, f in pairs(funcs) do
			debug.setupvalue(f, 1, w._ecs_world)
		end
	end
	return funcs
end

local m = {}

function m.new_world(config)
	local ecs = config.w
	local w = setmetatable({
		args = config,
		_memory = {},
		_memory_stat = setmetatable({start={}, finish={}}, {__close = finish_memory_stat}),
		_ecs = {},
		_methods = {},
		_group = {
			tags = {}
		},
		_create_queue = {},
		_destruct = {},
		w = ecs,
		_entity = ecs:visitor_create(),
	}, world)

	event.init(world)

	-- load systems and components from modules
	typeclass.init(w, config)

	if w._clibs then
		for _, name in ipairs(w._clibs) do
			w:clibs(name)
		end
		w._clibs = nil
	end
	return w
end

return m
