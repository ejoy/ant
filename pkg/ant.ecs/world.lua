local typeclass = require "typeclass"
local system = require "system"
local event = require "event"
local ltask = require "ltask"
local bgfx = require "bgfx"

local world = {}
world.__index = world

function world:pipeline_func(what)
	local w = self
	local funcs, symbols = system.lists(w, what)
	if not funcs or #funcs == 0 then
		return function() end
	end
	local ecs_world = w._ecs_world

	local STAT <const> = true
	if STAT and what == "_update" then
		local get_time = ltask.counter
		local dbg_print = bgfx.dbg_text_print
		local total = w._cpu_stat
		local printtext = {}
		local MaxFrame <const> = 10
		local MaxText <const> = 10
		local MaxName <const> = 48
		local CurFrame = 0
		for i = 1, #funcs do
			total[i] = 0
		end
		for i = 1, MaxText do
			printtext[i] = ""
		end
		return function()
			for i = 1, #funcs do
				local f = funcs[i]
				local now = get_time()
				f(ecs_world)
				total[i] = total[i] + (get_time() - now)
			end
			if CurFrame ~= MaxFrame then
				CurFrame = CurFrame + 1
			else
				CurFrame = 1
				local t = {}
				for i = 1, #funcs do
					t[total[i]] = i
				end
				table.sort(total)
				for i = 1, MaxText do
					local v = total[#total + 1 - i]
					local m = v / MaxFrame * 1000
					local name = symbols[t[v]]
					printtext[i] = name .. (" "):rep(MaxName-#name) .. (" | %.02fms   "):format(m)
				end
				for i = 1, #funcs do
					total[i] = 0
				end
			end
			dbg_print(0, 2, 0x02, "--- system")
			for i = 1, MaxText do
				dbg_print(2, 2+i, 0x02, printtext[i])
			end
		end
	end

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
	self:pipeline_func "_init" ()
	self.pipeline_update = self:pipeline_func "_update"
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
		_cpu_stat = {},
		_ecs = {},
		_methods = {},
		_frame = 0,
		_group = {
			tags = {}
		},
		_create_queue = {},
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
