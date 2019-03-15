local objcontroller = {}; objcontroller.__index = objcontroller

-- need work with "objcontroller_system"
local msgqueue = nil

local binding = {}; binding.__index = binding
function binding.new()
	return setmetatable({v={}}, binding)
end

function binding:check_add(name, keys)
	local b = self.v[name]
	if b == nil then
		b = {keys={}}
		self.v[name] = b
		self[#self+1] = name
		table.sort(self, function(a, b) return a > b end)
	end
	table.move(keys, 1, #keys, #b.keys+1, b.keys)
end

function binding:bind(name, cb)	
	local b = self.v[name]
	if b == nil then
		error(string.format("not found constant name:%s", name))
	end

	b.cb = cb
end

function binding:iter()	
	local function next(t, idx)
		idx = idx + 1
		local name = t[idx]
		if name then
			return idx, t.v[name]	
		end		
	end

	return next, self, 0
end

local tiggers = binding.new()
local constants = binding.new()

local function is_state_match(state1, state2)
	local function key_names(state)
		local t = {}
		for k in pairs(state) do
			t[#t+1] = k
		end
		return t
	end

	local keys1 = key_names(state1)
	local keys2 = key_names(state2)
	if #keys1 ~= #keys2 then
		return false
	end

	for idx, k1 in ipairs(keys1) do
		local k2 = keys2[idx]
		if k1 ~= k2 then
			return false
		end

		local v1 = state1[k1]
		local v2 = state2[k2]
		if v1 ~= v2 then
			return false
		end
	end

	return true
end

local function match_tigger_event(tigger, event)	
	local name = event.name
	if event.name ~= tigger.name then
		return false
	end

	if name == "mouse_click" then
		return 	event.what == tigger.what and 
				event.press == tigger.press
	elseif name == "mouse_move" then
		return is_state_match(event.state, tigger.state)
	elseif name == "mouse_wheel" then
		return true
	elseif name == "keyboard" then		
		return event.key == tigger.key and 
				event.press == tigger.press and
				is_state_match(event.state, tigger.state)
	end
	error "not implement"
end

local function match_const_event(const, event)
	local name = event.name
	if const.name ~= name then
		return false
	end

	if name == "mouse_click" then
		return event.what == const.what and event.press == const.press
	elseif name == "mouse_move" then
		return is_state_match(const.state, event.state)	
	elseif name == "mouse_wheel" then
		return true
	elseif name == "keyboard" then
		return const.key == event.key and
			is_state_match(const.state, event.state)
	end

	error "not implement"
end

local function add_event(event)
	assert(msgqueue)
	assert(event.name)
	-- tiger
	msgqueue.tiggers[#msgqueue.tiggers+1] = event

	-- constant
	local function find_new_slot(constants, event)
		for idx, e in ipairs(constants) do
			if match_const_event(e, event) then
				return idx
			end
		end
		return #constants+1
	end

	local function simulate_const_input(event)
		local name = event.name
		if name == "keyboard" or name == "mouse" then
			if event.press then
				event.value = 1
				return event
			else
				return nil
			end
		end

		return event
	end

	local function remove_const_event_by_name(eventlist, name)
		local idx = 1
		while idx <= #eventlist do
			local c = eventlist[idx]
			if c.name == event.name then
				table.remove(eventlist, idx)
			else
				idx = idx + 1
			end
		end		
	end

	local slot = find_new_slot(msgqueue.constants, event)
	local newevent = simulate_const_input(event)
	if newevent then
		msgqueue.constants[slot] = newevent
	else
		remove_const_event_by_name(msgqueue.constants, newevent)
	end
	
end

function objcontroller.init(msg)
	assert(msgqueue == nil)
	msgqueue = {
		tiggers = {},
		constants = {},
	}
	msg.observers:add  {
		mouse_click = function (_, what, press, x, y)
			add_event {name = "mouse_click", what=what, press=press, x=x, y=y}
		end,
		mouse_move = function (_, x, y, state)
			add_event {name = "mouse_move", x=x, y=y, state=state}
		end,
		mouse_wheel = function (_, x, y, delta)
			add_event {name = "mouse_wheel", x=x, y=y, delta=delta, press=delta ~= 0}
		end,
		keyboard = function (_, key, press, state)
			add_event {name = "keyboard", key=key, press=press, state=state}
		end,
		touch = function (...)
			error "not implement"
		end,
	}

	local defcfg = require "default_control_config"
	objcontroller.register(defcfg)
end

function objcontroller.register(cfg)
	local function update_map(srcmap, dstmap)
		if srcmap then
			for name, keys in pairs(srcmap) do
				dstmap:check_add(name, keys)
			end
		end
	end

	update_map(cfg.tigger, tiggers)
	update_map(cfg.constant, constants)
end

function objcontroller.bind_tigger(name, cb)
	tiggers:bind(name, cb)
end

function objcontroller.bind_constant(name, cb)
	constants:bind(name, cb)
end

local function update_tigger_event(eventlist, tiggers)
	for _, event in ipairs(eventlist) do
		for _, tigger in tiggers:iter() do
			local keys = tigger.keys
			local function find_key(keys, event) 
				for _, key in ipairs(keys) do
					if match_tigger_event(key, event) then
						return key
					end
				end
			end
			local key = find_key(keys, event)
			if key then
				local cb = tigger.cb
				if cb then
					cb(event, key)
				end
				break
			end
		end
	end
end

local function update_constant_event(eventlist, constants)
	for _, c in constants:iter() do
		local function find_event(eventlist, const)
			for _, key in ipairs(const.keys) do			
				for _, event in ipairs(eventlist) do
					if match_const_event(key, event) then
						return event, key
					end
				end
			end
		end

		local event, key = find_event(eventlist, c)	
		local cb = c.cb
		if cb then
			local value = event and event.value * key.scale or 0
			cb(value)
		end
	end
end

function objcontroller.update()
	assert(msgqueue)

	if msgqueue.tiggers then
		update_tigger_event(msgqueue.tiggers, tiggers)
		msgqueue.tiggers = {}
	end

	update_constant_event(msgqueue.constants, constants)	
end

return objcontroller