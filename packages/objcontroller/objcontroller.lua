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

local function add_event(event)
	assert(msgqueue)
	assert(event.name)

	local tt = msgqueue.tiggers
	if tt == nil then
		tt = {}
		msgqueue.tiggers = tt
	end
	tt[#tt+1] = event

	if event.press == nil then
		return
	end

	if event.press then
		local c = msgqueue.constants
		if c == nil then
			c = {}
			msgqueue.constants = c
		end

		c[#c+1] = event
	else
		local c = msgqueue.constants
		if c then
			local idx = 1
			while idx <= #c do
				local ec = c[idx]
				if ec.name == event.name then
					table.remove(c, idx)
				else
					idx = idx + 1
				end
			end
		end
	end
end

function objcontroller.init(msg)
	assert(msgqueue == nil)
	msgqueue = {}
	msg.observers:add  {
		mouse_click = function (_, what, press, x, y, state)
			add_event {name = "mouse_click", what=what, press=press, x=x, y=y, state=state}
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
				event.press == tigger.press and
				is_state_match(event.state, tigger.state)
	elseif name == "mouse_move" or name == "mouse_wheel" then
		return is_state_match(event.state, tigger.state)
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
		return 	event.what == const.what and
				is_state_match(const.state, event.state)
	elseif name == "mouse_move" or name == "mouse_wheel" then
		return is_state_match(const.state, event.state)	
	elseif name == "keyboard" then		
		return const.key == event.key and
			is_state_match(const.state, event.state)
	end

	error "not implement"
end

local function update_match_event(eventlist, match_eventlist, matchop, updateop)
	for _, e in ipairs(eventlist) do
		for _, me in match_eventlist:iter() do
			local keys = me.keys
			for _, key in ipairs(keys) do
				if matchop(key, e) then
					updateop(me, e, key)
				end
			end
		end
	end
end

function objcontroller.update()
	assert(msgqueue)

	if msgqueue.tiggers then
		update_match_event(msgqueue.tiggers, tiggers, 
		match_tigger_event,
		function (me, e) 
			local cb = me.cb
			if cb then
				cb(e)
			end
		end)

		msgqueue.tiggers = nil
	end

	if msgqueue.constants then
		update_match_event(msgqueue.constants, constants, 
		match_const_event,
		function (me, e, key)
			local cb = me.cb
			if cb then
				local value = e.value or key.value
				cb(e, value)
			end
		end)
	end
end

return objcontroller