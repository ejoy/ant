local typeclass = require "typeclass"
local system = require "system"
local policy = require "policy"
local event = require "event"
local stringify = import_package "ant.serialize".stringify
local assetmgr = import_package "ant.asset"

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
	w[eid] = {}
	w._entity[eid] = true
	return eid
end

local function instance_entity(w, entity)
	local eid = register_entity(w)
	local e = w[eid]
	setmetatable(e, {__index = entity.template})
	for _, c in ipairs(entity.unique) do
		if w._uniques[c] then
			error "unique component already exists"
		end
		w._uniques[c] = eid
	end
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
	return eid
end

local function instance_prefab(w, prefab, args)
	args = args or {}
	local res = {__class = prefab}
	for i, v in ipairs(prefab) do
		if v.prefab then
			res[i] = instance_prefab(w, v.prefab, v.data.args)
		else
			res[i] = instance_entity(w, v)
		end
	end
	setmetatable(res, {__index=args})
	for i, entity in ipairs(prefab) do
		if entity.data.action then
			for name, target in sortpairs(entity.data.action) do
				local object = w._class.action[name]
				assert(object and object.init)
				object.init(res, i, target)
			end
		end
	end
	setmetatable(res, nil)
	return res
end

local function create_entity_template(w, v)
	local res = policy.create(w, v.policy)
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
		data = v,
	}
end

function world:create_template(data)
	local prefab = {}
	for _, v in ipairs(data) do
		if v.prefab then
			prefab[#prefab+1] = {
				prefab = assetmgr.resource(v.prefab, self),
				data = v,
			}
		else
			prefab[#prefab+1] = create_entity_template(self, v)
		end
	end
	return prefab
end

function world:create_entity(v)
	local args = {}
	if v.action and v.action.mount then
		args["_mount"] = v.action.mount
		v.action.mount = "_mount"
	end
	local prefab = {create_entity_template(self, v)}
	local res = instance_prefab(self, prefab, args)
	return res[1], res
end

function world:instance(filename, args)
	local prefab = assetmgr.resource(filename, self)
	return instance_prefab(self, prefab, args)
end

function world:serialize(entities)
	local t = {}
	for _, class in ipairs(entities.__class) do
		if class.prefab then
			t[#t+1] = {
				prefab = tostring(class.prefab),
				args = next(class.args) ~= nil and class.args or nil,
			}
		else
			t[#t+1] = class.data
		end
	end
	return stringify(t)
end

function world:remove_entity(eid)
	local e = assert(self[eid])
	self[eid] = nil
	self._entity[eid] = nil

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
		local tc = w._class.component[c]
		if tc and tc.delete then
			tc.delete(component)
		end
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

local patch_table; do

	local function format_error(format, ...)
		error(format:format(...))
	end

	local function apply_patch(obj, patch)
		for k,v in pairs(patch) do
			local original = obj[k]
			if original == nil then
				format_error("the key %s in the patch is not exist in the original object", k)
			end
			if type(original) ~= "table" then
				if type(v) == "table" then
					format_error("patch a none-table key %s with a table", k)
				end
				obj[k] = v
			else
				-- it's sub tree
				if type(v) ~= "table" then
					format_error("patch a sub tree %s with a none-table", k)
				end
				obj[k] = patch_table(original, v)
			end
		end
	end

	function patch_table(src, patch)
		if patch._data ~= nil then
			-- patch is a resource proxy
			return patch
		end
		local obj
		if src._data ~= nil or src._patch == nil then
			-- src is shared
			obj = { _patch = false }
			for k,v in pairs(src) do
				obj[k] = v
			end
		else
			-- src._patch == false
			obj = src
		end
		apply_patch(obj, patch)
		return obj
	end
end

function world:set(eid, cname, patch)
	local e = self[eid]
	local oldc = e[cname]
	e[cname] = patch_table(oldc, patch)
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
		_slots = {},
	}, world)

	--init event
	event.init(world)
	world.sub = event.sub
	world.pub = event.pub
	world.unsub = event.unsub

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
