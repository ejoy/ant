local typeclass = require "typeclass"
local system = require "system"
local policy = require "policy"
local event = require "event"
local datalist = require "datalist"

local world = {}
world.__index = world

local function component_init(w, c, component)
	local tc = w:import_component(c)
	if tc and tc.methodfunc and tc.methodfunc.init then
		local res = tc.methodfunc.init(component)
		assert(type(res) == "table" or type(res) == "userdata")
		w._typeclass[res] = c
		return res
	end
	error(("component `%s` has no init function."):format(c))
end

local function component_delete(w, c, component)
    local tc = w:import_component(c)
    if tc and tc.methodfunc and tc.methodfunc.delete then
        tc.methodfunc.delete(component)
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

local function apply_policy(w, eid, component, transform, dataset)
	local e = w[eid]
	for _, c in ipairs(component) do
		e[c] = dataset[c]
		register_component(w, eid, c)
	end
	for _, f in ipairs(transform) do
		f(e, eid)
	end
end

function world:add_policy(eid, t)
	local policies, dataset = t.policy, t.data
	local component, transform = policy.add(self, eid, policies)
	apply_policy(self, eid, component, transform, dataset)
end

function world:init_entity(eid, dataset)
	local args = self._initargs[eid]
	apply_policy(self, eid, args.component, args.transform, dataset)
end

local function register_entity(w, t)
	if type(t) == 'string' then
		t = datalist.parse(t, function(args)
			return component_init(w, args[1], args[2])
		end)
	end
	local eid = w._entity_id + 1
	w._entity_id = eid
	w[eid] = {}
	w._entity[eid] = true

	local component, transform = policy.create(w, t.policy)
	w._initargs[eid] = {
		policy = t.policy,
		component = component,
		transform = transform,
	}
	return eid, t.data
end

function world:create_entity(t)
	local eid, dataset = register_entity(self, t)
	self:init_entity(eid, dataset)
	self:pub {"entity_created", eid}
	return eid
end

function world:reset_entity(eid, dataset)
	local removed = self._removed
	removed[#removed+1] = assert(self[eid])
	self:init_entity(eid, dataset)
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil
	self._initargs[eid] = nil

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
	local interface = self._interface
	local res = interface[fullname]
	if not res then
		typeclass.import_object(self, "interface", fullname)
		local object = self._class.interface[fullname]
		res = setmetatable({}, {__index = object.methodfunc})
		interface[fullname] = res
	end
	return res
end

function world:import_component(name)
	typeclass.import_object(self, "component", name)
	return self._class.component[name]
end

local m = {}

m.world_base = world

function m.new_world(config,world_class)
	-- print(world_class.name)
	local w = setmetatable({
		args = config,
		_entity = {},	-- entity id set
		_entity_id = 0,
		_set = setmetatable({}, { __mode = "kv" }),
		_removed = {},	-- A list of { eid, component_name, component } / { eid, entity }
		_switchs = {},	-- for enable/disable
		_uniques = {},
		_initargs = {},
		_interface = {},
		_typeclass = setmetatable({}, { __mode = "kv" }),
	}, world_class or world)

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
