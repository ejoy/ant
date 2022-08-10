local typeclass = require "typeclass"
local system = require "system"
local event = require "event"
local ltask = require "ltask"

local world = {}
world.__index = world

function world:pipeline_func(what)
	local funcs, symbols = system.lists(self, what)
	if not funcs or #funcs == 0 then
		return function() end
	end
	local ecs_world = self._ecs_world

	local STAT <const> = false
	if STAT and what == "_update" then
		return function()
			for i = 1, #funcs do
				local f = funcs[i]
				local symbol = symbols[i]
				--local _ <close> = self:memory_stat(symbol)
				local _ <close> = self:cpu_stat(symbol)
				f(ecs_world)
			end
			self:print_cpu_stat(0, 10)
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

local function finish_cpu_stat(cs)
	local _, now = ltask.now()
	local delta = now - cs.now
	local t = cs.total[cs.what]
	if t then
		cs.total[cs.what] = t + delta
	else
		cs.total[cs.what] = delta
	end
end

function world:cpu_stat(what)
	local cs = self._cpu_stat
	local _, now = ltask.now()
	cs.now = now
	cs.what = what
	return cs
end

function world:reset_cpu_stat()
	self._cpu_stat.total = {}
	self._cpu_stat.frame = 0
end

local function print_cpu_stat(w, per)
	local t = {}
	for k, v in pairs(w._cpu_stat.total) do
		t[#t+1] = {k, v}
	end
	table.sort(t, function (a, b)
		return a[2] > b[2]
	end)
	local s = {
		"",
		"cpu stat"
	}
	per = per or 1
	for _, v in ipairs(t) do
		local m = v[2] / per
		if m >= 0.01 then
			s[#s+1] = ("\t%s - %.02fms"):format(v[1], m)
		end
	end
	print(table.concat(s, "\n"))
end

function world:print_cpu_stat(skip, delta)
	skip = skip or 0
	delta = delta or 1

	local w = self
	local frame = w._cpu_stat.frame + 1
	w._cpu_stat.frame = frame

	if frame <= skip then
		w._cpu_stat.total = {}
		return
	elseif frame % delta ~= 0 then
		return
	end

	print_cpu_stat(w, frame-skip)
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
	if require "platform".OS:lower() == "windows" then
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
	local e = self.w:fetch(eid)
	return self.w:readall(e)
end

function world:remove_entity(eid)
	self.w:remove(eid)
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
		_cpu_stat = setmetatable({total={},frame=0}, {__close = finish_cpu_stat}),
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
