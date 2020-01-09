local ecs = ...
local world = ecs.world

local event = {} ; event.__index = event

function event:new(eid, component_type)
	local c = world[eid][component_type]
	assert(c.watcher == nil , "Can't new watcher more than once")
	-- A modifier is a table with meta, __newindex is init with a trigger.

	local data = {}
	local tigger = self._triggers[component_type]
	local meta = { __index = data, __newindex = tigger }
	c.watcher = setmetatable( { _rawdata = data , _meta = meta, _eid = eid }, meta )
	tigger(c.watcher, "_marked_init", true)
end

function event:each(component_type)
	local t = self._triggers[component_type]	-- lazy init iterator
	return self._iterators[component_type]
end

ecs.component "event" {}

local function event_singleton()
	local self = {}
	local all_sets = {}
	self._iterators = {}
	local function get_trigger(obj, name)
		local dirty_set = {}
		all_sets[name] = dirty_set

		-- __newindex is trigger only once (add eid to dirty set)
		local function trigger(watcher, key, value)
			dirty_set[#dirty_set+1] = watcher._eid
			local data = watcher._rawdata
			data[key] = value
			watcher._meta.__newindex = data
		end

		self._iterators[name] = function()
			local n = #dirty_set
			while n > 0 do
				local e = world[dirty_set[n]]
				if e then
					local c = e[name]
					if c then
						-- reset __newindex trigger
						local w = c.watcher
						local _marked_init = w._marked_init ~= nil
						w._marked_init = nil
						local rawdata = w._rawdata						
						local newrawdata = {}
						w._rawdata = newrawdata
						local meta = w._meta
						meta.__index = newrawdata
						meta.__newindex = trigger
						dirty_set[n] = nil
						return w._eid, rawdata, _marked_init
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
	return setmetatable(self, event)
end

ecs.singleton "event" (event_singleton())
