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

function binding:find(e, matchop)
	for i=1, #self do
		local name = self[i]
		local binding = self.v[name]
		local keys = binding.keys
		for j=1, #keys do
			local key = keys[j]
			if matchop(e, key) then
				return binding
			end
		end
	end
end

local tiggers = binding.new()
local constants = binding.new()

local event_check_offsets = {
	mouse = 2,
	keyboard = 0
}

local function match_event(event, record)
	local name = event.name
	if record.name ~= name then
		return false
	end

	local num_arg = #record
	if num_arg > 0 then
		
		local function is_record_match_event(e, r, t)
			local offset = assert(event_check_offsets[t])
			for i=1, #r do
				if r[i] ~= e[offset + i] then
					return false
				end
			end
			return true
		end

		if is_record_match_event(event, record, name) then
			if record.mouse == nil then
				return true
			end

			if event.mouse then
				return is_record_match_event(event.mouse, record.mouse, "mouse")
			end
		end
	end
	return false
end

local function add_event(event)
	assert(msgqueue)
	assert(event.name)
	
	msgqueue[#msgqueue+1] = event
end

local mousestate = {}
function objcontroller.init(msg)
	msgqueue = {}
	msg.observers:add  {
		mouse = function (_, ...)
			mousestate = {...}
			--print(select(1, ...), select(2, ...))
			add_event {name = "mouse", ...}
		end,
		mouse_wheel = function (_, ...)
			local delta = select(1, ...)
			add_event {name = "mouse_wheel", press=delta~=0, value=1, ...}
		end,
		keyboard = function (_, ...)
			add_event {name = "keyboard", mouse=mousestate, value=1, ...}
		end,
		touch = function (...)
			--error "not implement"
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

local function update_tigger_event(event, tiggers)	
	local binding = tiggers:find(event, match_event)
	if binding then
		local cb = binding.cb
		if cb then
			cb(event, binding)
		end
	end
end

local function update_constant_event(event, constants)
	for _, c in constants:iter() do
		local function find_event(e, const)
			local keys = const.keys
			for i=1, #keys do
				local key = keys[i]
				if match_event(e, key) then
					return e, key
				end
			end
		end

		local e, key = find_event(event, c)
		local cb = c.cb
		if cb then
			local value = e and e.value * key.scale or 0
			cb(value)
		end
	end
end

-- local last_msgqueue = {}
-- local function check_queue(new_msgqueue)
-- 	for _, e in ipairs(new_msgqueue) do
-- 		if e.press ~= nil and e.press == false then
-- 			local function has_event(e)
-- 				for idx, le in ipairs(last_msgqueue) do
-- 					if is_event_match(le, e) then
-- 						return idx
-- 					end
-- 				end
-- 			end

-- 			local idx = has_event(e)
-- 			if idx then
-- 				local le = last_msgqueue[idx]
-- 				assert(le.press)
-- 				table.remove(last_msgqueue, idx)
-- 			end
-- 		end
		
-- 	end
-- end

function objcontroller.update()
	for _, event in ipairs(msgqueue) do
		update_tigger_event(event, tiggers)
		update_constant_event(event, constants)
	end

	msgqueue = {}
end

return objcontroller