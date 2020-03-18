local typeclass = require "typeclass"
local system = require "system"
local component = require "component"
local policy = require "policy"
local event = require "event"
local datalist = require "datalist"

local component_init = component.init
local component_delete = component.delete

local world = {}
world.__index = world

local function create_component(w, c, args, disableSerialize)
	local ti = assert(w._class.component[c], c)
	if ti.type == 'tag' then
		assert(args == true or args == nil)
		return args
	end
	if not ti.type and ti.multiple then
		local res = component_init(w, ti, args, disableSerialize)
		assert(res ~= nil)
		for i = 1, #args do
			local r = component_init(w, ti, args[i], disableSerialize)
			assert(r ~= nil)
			res[i] = r
		end
		return res
	end
	local res = component_init(w, ti, args, disableSerialize)
	assert(res ~= nil)
	return res
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

function world:enable_tag(eid, c)
	local e = self[eid]
	local ti = assert(self._class.component[c], c)
	assert(ti.type == 'tag')
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
	local ti = assert(self._class.component[c], c)
	assert(ti.type == 'tag')
	if e[c] then
		self._set[c] = nil
		e[c] = nil
	end
end

local function sortcomponent(w, t)
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

local function apply_policy(w, eid, component, transform, dataset)
	local e = w[eid]
	local disableSerialize = dataset.serialize == nil
	for _, c in ipairs(component) do
		e[c] = create_component(w, c, dataset[c], disableSerialize)
		register_component(w, eid, c)
	end
	for _, f in ipairs(transform) do
		f(e)
	end
end

function world:add_policy(eid, t)
	local policies, dataset = t.policy, t.data
	local component, transform = policy.add(self, eid, policies)
	apply_policy(self, eid, component, transform, dataset)
end

function world:register_entity(policies, dataset)
	local eid = self._entity_id + 1
	self._entity_id = eid
	if dataset.serialize then
		self._uuids[dataset.serialize] = eid
	end
	self[eid] = {}
	self._entity[eid] = true
	self._policies[eid] = policies
	self._dataset[eid] = dataset
	return eid
end

function world:init_entity(eid)
	local policies, dataset = self._policies[eid], self._dataset[eid]
	local component, transform = policy.create(self, policies)
	apply_policy(self, eid, component, transform, dataset)
	self._dataset[eid] = nil
	self:pub {"entity_created", eid}
end

local function registerEntityEx(w, t)
	if type(t) == 'string' then
		local d = datalist.parse(t)
		return w:register_entity(d[1], d[2])
	end
	return w:register_entity(t.policy, t.data)
end

function world:create_entity(t)
	local eid = registerEntityEx(self, t)
	self:init_entity(eid)
	return eid
end

function world:create_entities(l)
	local entities = {}
	for _, t in ipairs(l) do
		entities[#entities+1] = registerEntityEx(self, t)
	end
	for _, eid in ipairs(entities) do
		self:init_entity(eid)
	end
end

function world:reset_entity(eid, dataset)
	local removed = self._removed
	removed[#removed+1] = assert(self[eid])
	self._dataset[eid] = dataset
	self:init_entity(eid)
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil

	local removed = self._removed
	removed[#removed+1] = e

	self:pub {"entity_removed", eid, e,}
end

function world:find_entity(uuid)
	local eid = self._uuids[uuid]
	if not eid then
		return
	end
	if self[eid] then
		return eid
	end
	self._uuids[uuid] = nil
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

local function each_component(t)
    return function(_, n)
        if n == 0 then
			return 1, t
        end
        if not t[n] then
            return
        end
        return n + 1, t[n]
    end, t, 0
end

function world:each_component(t)
    return each_component(t)
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

local function component_filter(world, minor_type)
	return function(set, index)
		local eid
		while true do
			index, eid = component_next(set, index)
			if eid then
				local e = world[eid]
				if e[minor_type] then
					return index, eid
				end
			else
				return
			end
		end
	end
end

function world:each2(ct1, ct2)
	local _,s = self:each(ct1)
	return component_filter(self, ct2), s, 0
end

local function remove_component(w, e, component_type, c)
	local ti = assert(w._class.component[component_type], component_type)
	if not ti.type and ti.multiple then
		for _, component in each_component(c) do
			component_delete(w, ti, component, e)
		end
	else
		component_delete(w, ti, c, e)
	end
end

local function remove_entity(w, e)
	for component_type, c in sortcomponent(w, e) do
		remove_component(w, e, component_type, c)
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
	local list = system.lists(self._systems, what)
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

function world:interface(name)
	return self._interface[name]
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
		_uuids = {},
		_policies = {},
		_dataset = {},
	}, world_class or world)

	--init event
	event.init(world)
	world.sub = event.sub
	world.pub = event.pub

	-- load systems and components from modules
	typeclass(w, config, config.loader or require "packageloader")

	-- init system
	w._systems = system.init(w._class.system, config.pipeline)

	-- init singleton
	local eid = w:create_entity {policy = {}, data = {}}
	local e = w[eid]
	for name, dataset in sortpairs(w._class.singleton) do
		e[name] = create_component(w, name, dataset[1], true)
		register_component(w, eid, name)
	end

	return w
end

function m.get_schema(...)
	local extract_schema = require "extract_schema"
	return extract_schema.run(world,...) 
end

return m
