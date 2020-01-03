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
		local res = assert(component_init(self, ti, args))
		for i = 1, #args do
			res[i] = assert(component_init(self, ti, args[i]))
		end
		return res
	end
	return assert(component_init(self, ti, args))
end

function world:register_component(eid, c)
	local set = self._set[c]
	if set then
		set[#set+1] = eid
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

function world:add_component_child(parent_com,child_name,child_type,child_value)
	local child_com = self:create_component(child_type, child_value)
	if parent_com.watcher then
		-- assert(parent_com.watcher[child_name]==nil,"watched value can't set twice in a frame:"..child_name,parent_com.watcher[child_name])
        parent_com.watcher[child_name] =  child_com
    else
        parent_com[child_name] = child_com
    end
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

function world:first_entity_id(c_type)
	local n, s, i = self:each(c_type)
	local _, eid = n(s, i)
	return eid
end

function world:first_entity(c_type)
	local eid = self:first_entity_id(c_type)
	if eid then
		return self[eid]
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

local function splitName(fullname, import)
	local package, name = fullname:match "^([^|]*)|(.*)$"
	if package then
		import(package)
		return name
	end
	return fullname
end

local function tableDelete(t, l)
	local delete = {}
	for k in pairs(t) do
		if not l[k] then
			delete[k] = true
		end
	end
	for k in pairs(delete) do
		t[k] = nil
	end
end

local function init_modules(w, config, loader)
	local policies = config.policy
	local systems = config.system
	local class = {}
	local imported = {}
	local reg
	local function import_package(name)
		if imported[name] then
			return false
		end
		imported[name] = true
		table.insert(class.packages, 1, name)
		local modules = assert(loader(name) , "load module " .. name .. " failed")
		if type(modules) == "table" then
			for _, m in ipairs(modules) do
				m(reg)
			end
		else
			modules(reg)
		end
		table.remove(class.packages, 1)
		return true
	end
	reg = typeclass(w, import_package, class)
	w.import = function(_, name)
		return import_package(name)
	end

	local policycut = {}
	local systemcut = {}
	local import_policy
	local import_system
	function import_system(k)
		local name = splitName(k, import_package)
		if systemcut[name] then
			return
		end
		systemcut[name] = true
		local v = class.system[name]
		if not v then
			error(("invalid system name: `%s`."):format(name))
		end
		if v.require_package then
			for _, name in ipairs(v.require_package) do
				import_package(name)
			end
		end
		if v.require_system then
			for _, k in ipairs(v.require_system) do
				import_system(k)
			end
		end
		if v.require_policy then
			for _, k in ipairs(v.require_policy) do
				import_policy(k)
			end
		end
	end
	function import_policy(k)
		local name = splitName(k, import_package)
		if policycut[name] then
			return
		end
		policycut[name] = true
		local v = class.policy[name]
		if not v then
			error(("invalid policy name: `%s`."):format(name))
		end
		if v.require_package then
			for _, name in ipairs(v.require_package) do
				import_package(name)
			end
		end
		if v.require_system then
			for _, k in ipairs(v.require_system) do
				import_system(k)
			end
		end
		if v.require_policy then
			for _, k in ipairs(v.require_policy) do
				import_policy(k)
			end
		end
	end
	for _, k in ipairs(policies) do
		import_policy(k)
	end
	for _, k in ipairs(systems) do
		import_system(k)
	end
	tableDelete(class.policy, policycut)
	tableDelete(class.system, systemcut)
	--tableDelete(class.component, componentcut)
	return class
end

function world:update_func(what)
	local list = system.lists(self._systems, what)
	if not list then
		return function() end
	end
	local switch = system.list_switch(list)
	self._switchs[what] = switch
	local proxy = self._systems.proxy
	local timer = import_package "ant.timer".cur_time
	return function()
		switch:update()
		for _, v in ipairs(list) do
			local name, f = v[1], v[2]
			self:pub {"system_begin",name,what,timer()}
			f(proxy[name])
			self:pub {"system_end",name,what,timer()}
		end
	end
end

function world:enable_system(name, enable)
	for _, switch in pairs(self._switchs) do
		switch:enable(name, enable)
	end
end

local m = {}

-- config.packages
-- config.systems
-- config.update_order
-- config.loader (optional)
-- config.args
function m.new_world(config)
	local w = setmetatable({
		args = config,
		_schema = {},
		_entity = {},	-- entity id set
		_entity_id = 0,
		_set = setmetatable({}, { __mode = "kv" }),
		_removed = {},	-- A list of { eid, component_name, component } / { eid, entity }
		_switchs = {},	-- for enable/disable
	}, world)

	--init event
	event.init(world)
	world.sub = event.sub
	world.pub = event.pub

	-- load systems and components from modules
	local class = init_modules(w, config, config.loader or require "packageloader")

	w._class = class
	component.solve(w)
	policy.solve(w)

	-- init system
	w._systems = system.init(class.system, class.singleton, config.pipeline)

	return w
end

return m
