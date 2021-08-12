local typeclass = require "typeclass"
local system = require "system"
local policy = require "policy"
local event = require "event"
local ltask = require "ltask"

local world = {}
world.__index = world

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

function world:enable_tag(eid, c)
	local e = self[eid]
	if not e[c] then
		e[c] = true
		local set = self._set[c]
		if set then
			set[#set+1] = eid
		end
	end
end

function world:disable_tag(eid, c)
	local e = assert(self[eid])
	if e[c] then
		self._set[c] = nil
		e[c] = nil
	end
end

local function register_entity(w)
	local eid = w._entity_id + 1
	w._entity_id = eid
	w._entity[eid] = true
	return eid
end

local function instance_entity(w, eid, entity, owned)
	if entity.template.camera then
		local icamera = w:interface "ant.camera|camera"
		icamera.create_entity(eid, entity.template)
		w._entity[eid] = nil
		return eid
	end
	local e = {}
	w[eid] = e
	setmetatable(e, {__index = entity.template, __owned = owned})
	for _, c in ipairs(entity.unique) do
		if w._uniques[c] then
			error "unique component already exists"
		end
		w._uniques[c] = eid
	end
	--for _, c in ipairs(entity.component) do
	--	if entity.template[c] == nil then
	--		error(("component `%s` must exists"):format(c))
	--	end
	--end
	for c in pairs(entity.template) do
		local set = w._set[c]
		if set then
			set[#set+1] = eid
		end
	end
	for _, c in ipairs(entity.component) do
		w:pub {"component_register", c, eid}
	end
	for _, f in ipairs(entity.process) do
		f(e)
	end
	w:pub {"entity_register", eid}
	return eid
end

local function run_action(w, res, prefab)
	for i, entity in ipairs(prefab.__class) do
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

local function instance_prefab(w, prefab, owned)
	local res = {__class = prefab.__class}
	for i, v in ipairs(prefab) do
		if v.prefab then
			res[i] = instance_prefab(w, v.prefab, owned)
		else
			res[i] = instance_entity(w, register_entity(w), v, owned)
		end
	end
	return res
end

function world:create_entity_template(v)
	local res = policy.create(self, v.policy)
	local e = {}
	for _, c in ipairs(res.component) do
		local init = res.init_component[c]
		local component = v.data[c]
		if component ~= nil then
			if init then
				e[c] = init(component)
			else
				e[c] = component
			end
		end
	end
	for _, f in ipairs(res.process_prefab) do
		f(e)
	end
	return {
		component = res.component,
		process = res.process_entity,
		unique = res.unique_component,
		template = e,
	}
end

function world:register_entity()
	local eid = self._entity_id + 1
	self._entity_id = eid
	return eid
end

function world:create_entity(v)
	local args = {}
	if v.action and v.action.mount then
		args["_mount"] = v.action.mount
		v.action.mount = "_mount"
	end
	local prefab = {__class={v}, self:create_entity_template(v)}
	local res = self:instance_prefab(prefab, args, true)
	return res[1], res
end

function world:rebuild_entity(eid, data)
	local args = {}
	if data.action and data.action.mount then
		args["_mount"] = data.action.mount
		data.action.mount = "_mount"
	end
	local w = self
	local template = w:create_entity_template(data)
	local prefab = {
		__class = {data},
		template,
	}
	local res = {
		__class = {data},
		instance_entity(w, eid, template, true),
	}
	if args then
		for k, v in pairs(args) do
			res[k] = v -- TODO?
		end
	end
	run_action(self, res, prefab)
	return res[1], res
end

function world:instance_prefab(prefab, args, owned)
	local res = instance_prefab(self, prefab, owned)
	if args then
		for k, v in pairs(args) do
			res[k] = v -- TODO?
		end
	end
	run_action(self, res, prefab)
	return res
end

function world:remove_entity(eid)
	self:enable_tag(eid, "removed")
end

local function component_next(set, index)
	local n = #set
	index = index + 1
	while index <= n do
		local eid = set[index]
		if eid == nil then
			return
		end
		local exist = set.entity[eid]
		-- NOTICE: component may removed from entity
		if exist then
			return index, eid
		end
		set[index] = set[n]
		set[n] = nil
		n = n - 1
	end
end

local function component_set(w, component_type)
	local s = w._set[component_type]
	if s == nil then
		s = { entity = w._entity }
		for eid in pairs(w._entity) do
			local e = w[eid]
			if e[component_type] ~= nil then
				s[#s+1] = eid
			end
		end
		w._set[component_type] = s
	end
	return s
end

function world:each(component_type)
	local s = component_set(self, component_type)
	return component_next, s, 0
end

local function split(str)
    local r = {}
    str:gsub('[^ ]*', function (w) r[#r+1] = w end)
    return r
end

function world:select(pattern)
	local components = split(pattern)
	local s = component_set(self, components[1])
	local n = #components
	local index
	return function (set)
		local eid
		index, eid = component_next(set, index)
		if not index then
			return
		end
		local e = self[eid]
		local i = 2
		while i > n do
			if e[components[i]] == nil then
				index, eid = component_next(set, index)
				i = 2
			else
				i = i + 1
			end
		end
		return e
	end, s, 0
end

function world:count(component_type)
	local s = component_set(self, component_type)
	return #s
end

function world:singleton_entity_id(c_type)
	return self._uniques[c_type]
end

function world:singleton_entity(c_type)
	local eid = self._uniques[c_type]
	if eid then
		return self[eid]
	end
end

function world:singleton(c_type)
	local eid = self._uniques[c_type]
	if eid then
		return self[eid][c_type]
	end
end

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

local function remove_entity(w, e)
	for c, component in sortpairs(e) do
		local tc = w._class.component[c]
		if tc and tc.delete then
			tc.delete(component)
		end
	end
	local mt = getmetatable(e)
	if mt and mt.__owned then
		remove_entity(w, mt.__index)
	end
end

local function clear_removed(w)
	for _, eid in w:each "removed" do
		local e = w[eid]
		w[eid] = nil
		w._entity[eid] = nil
		remove_entity(w, e)
	end
end

function world:pipeline_init()
	self:pipeline_func "init" ()
	self._update_func = self:pipeline_func "update"
end

function world:pipeline_exit()
	self:pipeline_func "exit" ()
	for eid in sortpairs(self._entity) do
		self:remove_entity(eid)
	end
	clear_removed(self)
end

function world:pipeline_update()
	self._update_func()
	clear_removed(self)
end

function world:enable_system(name, enable)
	for _, switch in pairs(self._switchs) do
		switch:enable(name, enable)
	end
end

function world:import(fullname)
	typeclass.import_decl(self, fullname)
end

function world:interface(fullname)
	return self._class.interface[fullname]
end

local m = {}

function m.new_world(config)
	local w = setmetatable({
		args = config,
		_entity = {},	-- entity id set
		_entity_id = 0,
		_set = setmetatable({}, { __mode = "kv" }),
		_removed = {},	-- A list of { eid, component_name, component } / { eid, entity }
		_switchs = {},	-- for enable/disable
		_uniques = {},
		_memory = {},
		_memory_stat = setmetatable({start={}, finish={}}, {__close = finish_memory_stat}),
		_cpu_stat = setmetatable({total={}}, {__close = finish_cpu_stat}),
		w = config.w
	}, world)

	event.init(world)

	w.component = function(name)
		return function (args)
			local tc = w._class.component[name]
			if tc and tc.init then
				return tc.init(args)
			end
			error(("component `%s` has no init function."):format(name))
		end
	end

	-- load systems and components from modules
	typeclass.init(w, config)

	return w
end

return m
