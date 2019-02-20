--luacheck: globals log
local log = log and log(...) or print

local typeclass = require "typeclass"
local system = require "system"
local component = require "component"
local create_schema = require "schema"

local ecs = {}
local world = {} ; world.__index = world

function world:create_component(c)
	assert(self._component_type[c], c)
	return self._component_type[c].init()
end

function world:create_component_with_args(c, args)
	assert(self._component_type[c], c)
	return self._component_type[c].initp(args)
end

function world:register_component(eid, c)
	local set = self._set[c]
	if set then
		set[#set+1] = eid
	end
	local newset = self._newset[c]
	if newset then
		newset[#newset+1] = eid
	end
end

function world:register_entity()
	local entity_id = self._entity_id + 1
	self._entity_id = entity_id
	self._entity[entity_id] = true
	return entity_id
end

local function new_component(w, eid, c, ...)
	if c then
		local entity = assert(w[eid])
		if entity[c] then
			error(string.format("multiple component defined:%s", c))
		end
		entity[c] = w:create_component(c)
		w:register_component(eid, c)
		new_component(w, eid, ...)
	end
end

function world:add_component(eid, ...)
	new_component(self, eid, ...)
end

function world:add_single_component(eid, component_type, args)
	self:register_component(eid, component_type)
	local e = self[eid]
	e[component_type] = self:create_component_with_args(component_type, args)
end

function world:remove_component(eid, component_type)
	local e = assert(self[eid])
	assert(e[component_type] ~= nil)
	self._set[component_type] = nil
	-- defer delete , see world:remove_reset
	local removed = self._removed
	removed[#removed+1] = { eid, component_type, e[component_type] }
	e[component_type] = nil
end

function world:component_list(eid)
	local e = assert(self[eid])
	local r = {}
	for k in pairs(e) do
		table.insert(r, k)
	end
	return r
end

local function create_entity(w, id)
	w[id] = {}
	w._entity[id] = true
end

function world:new_entity(...)
	local entity_id = self._entity_id + 1
	self._entity_id = entity_id
	create_entity(self, entity_id)
	new_component(self, entity_id, ...)

	return entity_id
end

function world:create_entity(t)
	local eid = self._entity_id + 1
	self._entity_id = eid
	create_entity(self, eid)
	local entity = self[eid]
	for c, args in pairs(t) do
		self:register_component(eid, c)
		entity[c] = self:create_component_with_args(c, args)
	end
	return eid
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil

	local removed = self._removed
	removed[#removed+1] = { eid, e }
	-- defer delete , see world:remove_reset
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

function world:first_entity_id(c_type)
	local n, s, i = self:each(c_type)
	local _, eid = n(s, i)
	return eid
end

function world:first_entity(c_type)
	local eid = self:first_entity_id(c_type)
	if eid == nil then
		return nil
	end
	return self[eid]
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

local function new_component_next(set)
	local n = #set
	while n >= 0 do
		local eid = set[n]
		if set.entity[eid] then
			set[n] = nil
			return eid
		end
		n = n - 1
	end
end

function world:each_new(component_type)
	local s = self._newset[component_type]
	if s == nil then
		s = { entity = self._entity }
		for index, eid in self:each(component_type) do
			s[index] = eid
		end
		self._newset[component_type] = s
	end
	return new_component_next, s
end

function world:clear_removed()
	local set = self._removed
	local typeclass = self._component_type

	for i = #set,1,-1 do
		local item = set[i]
		set[i] = nil
		local c = item[3]
		if c ~= nil then
			-- delete component
			local component_type = item[2]
			local del = typeclass[component_type].delete
			if del then
				del(c)
			end
		else
			local e = item[2]
			-- delete entity
			for component_type, c in pairs(e) do
				local del = typeclass[component_type].delete
				if del then
					del(c)
				end
			end
		end
	end
end

local function dummy_iter() end

function world:each_removed(component_type)
	local removed_set

	local set = self._removed
	for i = 1, #set do
		local item = set[i]
		local eid = item[1]
		local c = item[3]	-- { eid, component_type, c }
		if c ~= nil then
			local ctype = item[2]
			if ctype == component_type then
				removed_set = removed_set or {}
				removed_set[eid] = true
			end
		else
			local e = item[2]
			if e[component_type] ~= nil then
				removed_set = removed_set or {}
				removed_set[eid] = true
			end
		end
	end

	if removed_set then
		return pairs(removed_set)
	else
		return dummy_iter
	end
end

local function init_modules(w, packages, systems, loader)
	local class = {}
	local imported = {}
	local reg
	local function import(name)
		if imported[name] then
			return
		end
		imported[name] = true
		local modules = assert(loader(name) , "load module " .. name .. " failed")
		if type(modules) == "table" then
			for _, m in ipairs(modules) do
				m(reg)
			end
		else
			modules(reg)
		end
	end
	reg = typeclass(w, import, class)

	for _, name in ipairs(packages) do
		import(name)
	end

	local cut = {}

	local function solve_depend(k)
		if cut[k] then
			return
		end
		cut[k] = true
		local v = class.system[k]
		assert(v, k)
		if v.depend then
			for _, subk in ipairs(v.depend) do
				solve_depend(subk)
			end
		end
		if v.dependby then
			for _, subk in ipairs(v.dependby) do
				solve_depend(subk)
			end
		end
	end

	for _, k in ipairs(systems) do
		solve_depend(k)
	end

	local delete = {}
	for k in pairs(class.system) do
		if not cut[k] then
			delete[k] = true
		end
	end
	for k in pairs(delete) do
		class.system[k] = nil
	end
	return class
end

function world:groups()
	local keys = {}
	for k in pairs(self._systems) do
		keys[#keys+1] = k
	end
	return keys
end

function world:update_func(what, order)
	local list = self._systems[what]
	if not list then
		return function() end
	end
	if order then
		list = system.order_list(list, order)
	end
	local switch = system.list_switch(list)
	self._switchs[what] = switch
	local proxy = self._singleton_proxy
	return function()
		switch:update()
		for _, v in ipairs(list) do
			local name, f = v[1], v[2]
			f(proxy[name])
		end
	end
end

function world:enable_system(name, enable)
	for _, switch in pairs(self._switchs) do
		switch:enable(name, enable)
	end
end

-- config.packages
-- config.systems
-- config.update_order
-- config.loader (optional)
-- config.args
function ecs.new_world(config)
	local w = setmetatable({
		args = config.args,
		_component_type = {},	-- component type objects
		schema = create_schema.new(),

		_entity = {},	-- entity id set
		_entity_id = 0,
		_set = setmetatable({}, { __mode = "kv" }),
		_newset = {},
		_removed = {},	-- A list of { eid, component_name, component } / { eid, entity }
		_switchs = {},	-- for enable/disable
	}, world)

	w.schema:typedef("tag", "boolean", true)

	-- load systems and components from modules
	local class = init_modules(w, config.packages, config.systems, config.loader or require "packageloader")

	w.schema:check()

	for k,v in pairs(w.schema.map) do
		w._component_type[k] = component(v, w)
	end

	-- init system
	w._systems = system.lists(class.system)
	w._singleton_proxy = system.proxy(class.system, class.singleton_component)

	return w
end

return ecs
