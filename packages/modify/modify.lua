local ecs = ...

local world = ecs.world
local schema = ecs.schema

local modify = {} ; modify.__index = modify

function modify:new(eid, component_type)
	local c = world[eid][component_type]
	assert(c.modify == nil , "Can't new modify more than once")
	-- A modifier is a table with meta, __newindex is init with a trigger.

	local data = {}
	local meta = { __index = data, __newindex = self._triggers[component_type] }
	c.modify = setmetatable( { _rawdata = data , _meta = meta, _eid = eid }, meta )
end

function modify:each(component_type)
	local t = self._triggers[component_type]	-- lazy init iterator
	return self._iterators[component_type]
end

local modify_singleton = ecs.singleton_component "modify"

function modify_singleton.init()
	local self = {}
	local all_sets = {}
	self._iterators = {}
	local function get_trigger(obj, name)
		local dirty_set = {}
		all_sets[name] = dirty_set

		-- __newindex is trigger only once (add eid to dirty set)
		local function trigger(modifier, key, value)
			dirty_set[#dirty_set+1] = modifier._eid
			local data = modifier._rawdata
			data[key] = value
			modifier._meta.__newindex = data
		end

		self._iterators[name] = function()
			local n = #dirty_set
			while n > 0 do
				local e = world[dirty_set[n]]
				if e then
					local c = e[name]
					if c then
						-- reset __newindex trigger
						local m = c.modify
						local rawdata = m._rawdata
						local newrawdata = {}
						m._rawdata = newrawdata
						local meta = m._meta
						meta.__index = newrawdata
						meta.__newindex = trigger
						dirty_set[n] = nil
						return m._eid, rawdata
					end
				end
				dirty_set[n] = nil
				n = n - 1
			end
		end

		obj[name] = trigger
		return trigger
	end

	self._triggers = setmetatable( {} , { __index = get_trigger } )
	return setmetatable(self, modify)
end
