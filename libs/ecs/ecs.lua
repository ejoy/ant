local require = import and import(...) or require
local log = log and log(...) or print

local typeclass = require "typeclass"
local system = require "system"
local component = require "component"

local ecs = {}
local world = {} ; world.__index = world

local function new_component(w, eid, c, ...)
	if c then
		local entity = assert(w[eid])
		entity[c] = w._component_type[c].new()
		local nc = w._notifycomponent[c]
		if nc then
			table.insert(nc, eid)
		end
		new_component(w, entity, ...)
	end
end

function world:add_component(eid, ...)
	new_component(self, eid, ...)
end

function world:remove_component(eid, component_type)
	local e = assert(self[eid])
	assert(e[component_type] ~= nil)
	self._set[component_type] = nil
	e[component_type] = nil
end

function world:change_component(eid, component_type)
	local cc = self._changecomponent[component_type]
	if cc then
		cc[eid] = true
	end
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
	local e = setmetatable({}, w._entity_meta)
	w[id] = e
	w._entity[id] = true
end

function world:new_entity(...)
	local entity_id = self._entity_id + 1
	self._entity_id = entity_id
	create_entity(self, entity_id)
	new_component(self, entity_id, ...)

	return entity_id
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

local function init_notify(w, notifies)
	for cname in pairs(notifies) do
		w._notifycomponent[cname] = {}
		w._changecomponent[cname] = {}
		w._notifyset[cname] = { n = 0 }
	end
end

-- config.modules
-- config.update_order
function ecs.new_world(config)
	local w = setmetatable({
		_component_type = {},	-- component type objects
		update = nil,	-- update systems
		notify = nil,

		_entity = {},	-- entity id set
		_entity_id = 0,
		_entity_meta = { __index = nil },
		_notifycomponent = {},	-- component_name : { eid_list }
		_changecomponent = {},	-- component_name : { eid_list }
		_notifyset = {},	-- component_name : { n = number, eid_list }
		_set = setmetatable({}, { __mode = "kv" }),
	}, world)

	-- load systems and components from modules
	local reg, class = typeclass(w)
	for _, module in ipairs(config.modules) do
		module(reg)
	end

	for k,v in pairs(class.component) do
		w._component_type[k] = component(v)
	end

	-- init system
	local singletons = system.singleton(class.system, w._component_type)
	local proxy = system.proxy(class.system, w._component_type, singletons)
	local system_methods = system.component_methods(class.system, w._component_type)
	local init_list = system.init_list(class.system, proxy)
	local meta = w._entity_meta

	local update_list = system.update_list(class.system, config.update_order)
	function w.update ()
		for _, v in ipairs(update_list) do
			local name, f = v[1], v[2]
			meta.__index = system_methods[name]
			f(proxy[name])
		end
	end

	local notify_list = system.notify_list(class.system, proxy, system_methods)
	init_notify(w, notify_list)

	function w.notify()
		local _changecomponent = w._changecomponent
		local _notifyset = w._notifyset

		for c, newset in pairs(w._notifycomponent) do
			local n = #newset
			local changeset = _changecomponent[c]
			local notifyset = _notifyset[c]
			for i = 1, n do
				local new_id = newset[i]
				if changeset[new_id] then
					changeset[new_id] = nil
				end
				notifyset[i] = new_id
				newset[i] = nil
			end

			for change_id in pairs(changeset) do
				changeset[change_id] = nil
				n = n + 1
				notifyset[n] = change_id
			end
			for i = n+1, notifyset.n do
				notifyset[i] = nil
			end
			notifyset.n = n

			if n > 0 then
				for _, functor in ipairs(notify_list[c]) do
					local f, inst, methods = functor[1],functor[2],functor[3]
					-- binding apis
					meta.__index = methods
					f(inst, notifyset)
				end
			end
		end
	end

	-- call init functions
	for _, v in ipairs(init_list) do
		local name, f = v[1], v[2]
		meta.__index = system_methods[name]
		log("Init system %s", name)
		f(proxy[name])
	end

	return w
end

return ecs
