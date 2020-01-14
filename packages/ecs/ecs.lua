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

function world:create_component(c, args)
	local ti = assert(self._class.component[c], c)
	if ti.type == 'tag' then
		assert(args == true or args == nil)
		return args
	end
	if not ti.type and ti.multiple then
		local res = component_init(self, ti, args)
		assert(res ~= nil)
		for i = 1, #args do
			local r = component_init(self, ti, args[i])
			assert(r ~= nil)
			res[i] = r
		end
		return res
	end
	local res = component_init(self, ti, args)
	assert(res ~= nil)
	return res
end

function world:register_component(eid, c)
	local set = self._set[c]
	if set then
		set[#set+1] = eid
	end
	if self._class.unique[c] then
		if self._uniques[c] then
			error "unique component already exists"
		end
		self._uniques[c] = eid
	end
	self:pub {"component_register", c, eid}
end

function world:add_component(eid, component_type, args)
	local e = self[eid]
	local ti = assert(self._class.component[component_type], component_type)
	if not ti.type and ti.multiple then
		local c = e[component_type]
		if not c then
			e[component_type] = self:create_component(component_type, args)
			self:register_component(eid, component_type)
		else
			c[#c+1] = self:create_component(component_type, args)
		end
		return
	end
	e[component_type] = self:create_component(component_type, args)
	self:register_component(eid, component_type)
end

function world:remove_component(eid, c)
	local e = assert(self[eid])
	assert(e[c] ~= nil)
	self._set[c] = nil
	-- defer delete , see world:remove_reset
	local removed = self._removed
	removed[#removed+1] = { eid, e, c }

	self:pub {"component_removed", c, eid, e}
	e[c] = nil
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

function world:register_entity()
	local eid = self._entity_id + 1
	self._entity_id = eid
	return eid
end

local function apply_policy(w, eid, component, transform, dataset)
	local e = w[eid]
	for _, c in ipairs(component) do
		e[c] = w:create_component(c, dataset[c])
		w:register_component(eid, c)
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

function world:set_entity(eid, policies, dataset)
	local component, transform = policy.create(self, policies)
	self[eid] = {}
	self._entity[eid] = true
	apply_policy(self, eid, component, transform, dataset)
	self:pub {"entity_created", eid}
end

function world:create_entity(t)
	local eid = self:register_entity()
	if type(t) == 'string' then
		local d = datalist.parse(t)
		self:set_entity(eid, d[1], d[2])
	else
		self:set_entity(eid, t.policy, t.data)
	end
	return eid
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil

	local removed = self._removed
	removed[#removed+1] = { eid, e }

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
		local item = set[i]
		set[i] = nil
		local e = item[2]
		local component_type = item[3]
		if component_type ~= nil then
			remove_component(self, e, component_type, e[component_type])
		else
			remove_entity(self, e)
		end
	end
end

local baselib = require "bgfx.baselib"
local time_counter = baselib.HP_counter
local time_freq    = baselib.HP_frequency / 1000
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
			local f, proxy, name = v[1], v[2], v[3]
			self:pub {"system_begin",name,what,gettime()}
			f(proxy)
			self:pub {"system_end",name,what,gettime()}
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

function m.new_world(config)
	local w = setmetatable({
		args = config,
		_entity = {},	-- entity id set
		_entity_id = 0,
		_set = setmetatable({}, { __mode = "kv" }),
		_removed = {},	-- A list of { eid, component_name, component } / { eid, entity }
		_switchs = {},	-- for enable/disable
		_uniques = {},
	}, world)

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
		e[name] = w:create_component(name, dataset[1])
		w:register_component(eid, name)
	end

	return w
end

return m
