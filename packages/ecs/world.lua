local typeclass = require "typeclass"
local system = require "system"
local event = require "event"
local ltask = require "ltask"

local world = {}
world.__index = world

function world:pipeline_func(what)
	local list = system.lists(self, what)
	if not list then
		return function() end
	end
	local switch = system.list_switch(list)
	self._switchs[what] = switch
	return function()
		switch:update()
		for i = 1, #list do
			local v = list[i]
			local f, proxy = v[1], v[2]
			--local key = v[5] .. "|" .. v[3] .. "." .. v[4]
			--local _ <close> = self:memory_stat(key)
			--local _ <close> = self:cpu_stat(key)
			f(proxy)
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

function world:print_cpu_stat()
	local t = {}
	for k, v in pairs(self._cpu_stat.total) do
		t[#t+1] = {k, v}
	end
	table.sort(t, function (a, b)
		return a[2] > b[2]
	end)
	local s = {
		"",
		"cpu stat"
	}
	for i, v in ipairs(t) do
		s[#s+1] = ("\t%s - %d"):format(v[1], v[2])
	end
	print(table.concat(s, "\n"))
end

function world:pipeline_init()
	self:pipeline_func "_init" ()
	self.pipeline_update = self:pipeline_func "_update"
	self.pipeline_update_end = self:pipeline_func "update_end"
end

function world:pipeline_exit()
	self:pipeline_func "exit" ()
end

function world:enable_system(name, enable)
	for _, switch in pairs(self._switchs) do
		switch:enable(name, enable)
	end
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

local m = {}

function m.new_world(config)
	local w = setmetatable({
		args = config,
		_switchs = {},	-- for enable/disable
		_memory = {},
		_memory_stat = setmetatable({start={}, finish={}}, {__close = finish_memory_stat}),
		_cpu_stat = setmetatable({total={}}, {__close = finish_cpu_stat}),
		_ecs = {},
		_methods = {},
		_frame = 0,
		w = config.w
	}, world)

	event.init(world)

	-- load systems and components from modules
	typeclass.init(w, config)

	return w
end

return m
