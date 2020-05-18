local typeclass = require "typeclass"
local system = require "system"
local policy = require "policy"
local event = require "event"
local datalist = require "datalist"
local fs = require "filesystem"

local world = {}
world.__index = world

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    assert(getmetatable(t) == nil)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepcopy(v)
    end
    return copy
end

local function component_init(w, c, component)
	local tc = w._class.component[c]
	if tc and tc.init then
		local res = tc.init(component)
		assert(type(res) == "table" or type(res) == "userdata")
		w._typeclass[res] = c
		return res
	end
	error(("component `%s` has no init function."):format(c))
end

local function component_delete(w, c, component)
    local tc = w._class.component[c]
    if tc and tc.delete then
        tc.delete(component)
    end
end

local function component_copy(w, component)
	local name = w._typeclass[component]
	if name then
		local tc = w._class.component[name]
		if tc and tc.copy then
			return tc.copy(component)
		end
		return component
	else
		return deepcopy(component)
	end
end

local function register_component(w, eid, c)
	local set = w._set[c]
	if set then
		set[#set+1] = eid
	end
	if w._class.unique[c] then
		if w._uniques[c] then
			error "unique component already exists"
		end
		w._uniques[c] = eid
	end
	w:pub {"component_register", c, eid}
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

function world:add_component(eid, c, data)
	local e = assert(self[eid])
	assert(e[c] == nil)
	e[c] = data
	register_component(self, eid, c)
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

function world:add_policy(eid, t)
	local policies, dataset = t.policy, t.data
	local res = policy.add(self, eid, policies)
	local e = self[eid]
	for _, c in ipairs(res.component) do
		e[c] = dataset[c]
	end
	for _, f in ipairs(res.process_prefab) do
		f(e)
	end
	for c in pairs(res.register_component) do
		register_component(self, eid, c)
	end
	for _, f in ipairs(res.process_entity) do
		f(e)
	end
end

function world:component_init(name, v)
	return component_init(self, name, v)
end

function world:component_delete(name, v)
	component_delete(self, name, v)
end

local function register_entity(w)
	local eid = w._entity_id + 1
	w._entity_id = eid
	w[eid] = {}
	w._entity[eid] = true
	return eid
end

local function create_prefab_from_entity(w, t)
	local policies, dataset = t.policy, t.data
	local info = policy.create(w, policies)
	local action = t.connection or {}
	local args = {
		connection = {}
	}
	for i, v in ipairs(action) do
		args.connection["value_"..i] = v[2]
		v[3] = "value_"..i
		v[2] = 1
	end
	local e = {}
	for _, c in ipairs(info.component) do
		e[c] = dataset[c]
	end
	for _, f in ipairs(info.process_prefab) do
		f(e)
	end
	return {
		entities = {{
			policy = info,
			dataset = e,
		}},
		connection = action,
	}, args
end

local function read_data(w, filename)
	local f = assert(fs.open(fs.path(filename), 'rb'))
	local data = f:read 'a'
	f:close()
	return datalist.parse(data, function(v)
		return component_init(w, v[1], v[2])
	end)
end

local function create_prefab(w, filename)
	local t = read_data(w, filename)
	local prefab = {
		entities = {},
		connection = t[1],
	}
	for i = 2, #t do
		local policies, dataset = t[i].policy, t[i].data
		local info = policy.create(w, policies)
		local e = {}
		for _, c in ipairs(info.component) do
			e[c] = dataset[c]
		end
		for _, f in ipairs(info.process_prefab) do
			f(e)
		end
		prefab.entities[i-1] = {
			policy = info,
			dataset = e,
		}
	end
	return prefab
end

local function instance(w, prefab, args)
	local res = {}
	for i, entity in ipairs(prefab.entities) do
		local eid = register_entity(w)
		local e = w[eid]
		for c in pairs(entity.policy.register_component) do
			register_component(w, eid, c)
		end
		for k, v in pairs(entity.dataset) do
			if entity.policy.writable[k] or (args and args.writable and args.writable[i] and args.writable[i][k]) then
				e[k] = component_copy(w, v)
			else
				e[k] = v
			end
		end
		for _, f in ipairs(entity.policy.process_entity) do
			f(e)
		end
		w._prefabs[eid] = entity
		res[i] = eid
	end
	for _, connection in ipairs(prefab.connection) do
		local name, source, target = connection[1], connection[2], connection[3]
		local object = w._class.connection[name]
		assert(object and object.init)
		object.init(w[res[source]], res[target] or args.connection[target] or nil)
	end
	return res
end

function world:create_entity(data)
	local prefab, args = create_prefab_from_entity(self, data)
	local entities = instance(self, prefab, args)
	return entities[1]
end

function world:instance(filename, args)
	local prefab = create_prefab(self, filename)
	return instance(self, prefab, args)
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil
	self._prefabs[eid] = nil

	local removed = self._removed
	removed[#removed+1] = e

	self:pub {"entity_removed", eid, e,}
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

function world:each(component_type)
	local s = self._set[component_type]
	if s == nil then
		s = { entity = self._entity }
		for eid in pairs(self._entity) do
			local e = self[eid]
			if e[component_type] ~= nil then
				s[#s+1] = eid
			end
		end
		self._set[component_type] = s
	end
	return component_next, s, 0
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

local function remove_entity(w, e)
	for c, component in sortpairs(e) do
		component_delete(w, c, component)
	end
end

function world:clear_removed()
	local set = self._removed
	for i = #set,1,-1 do
		local e = set[i]
		set[i] = nil
		remove_entity(self, e)
	end
end

local timer = require "platform.timer"
local time_counter = timer.counter
local time_freq    = timer.frequency() / 1000
local function gettime()
	return time_counter() / time_freq
end
function world:update_func(what)
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
			local f, proxy, name, step_name = v[1], v[2], v[3], v[4]
			self:pub {"system_hook","begin",name,what,step_name,gettime()}
			f(proxy)
			self:pub {"system_hook","end",name,what,step_name,gettime()}
		end
	end
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

function world:connection(fullname, ...)
	local object = self._class.connection[fullname]
	assert(object and object.init)
	object.init(...)
end

function world:signal_on(name, f)
	self._slots[name] = f
end

function world:signal_hook(name, newf)
    local f = self._slots[name]
	if f then
		self._slots[name] = function(...)
			if not newf(...) then
				f(...)
			end
		end
	else
		self._slots[name] = newf
    end
end

function world:signal_emit(name, ...)
	local f = self._slots[name]
	if f then
		f(...)
	end
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
		_prefabs = {},
		_slots = {},
		_typeclass = setmetatable({}, { __mode = "kv" }),
	}, world)

	--init event
	event.init(world)
	world.sub = event.sub
	world.pub = event.pub
	world.unsub = event.unsub

	w.component = setmetatable({}, {__index = function(_, name)
		return function (_, args)
			return component_init(w, name, args)
		end
	end})

	-- load systems and components from modules
	typeclass.init(w, config)

	return w
end

return m
