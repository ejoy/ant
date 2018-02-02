local rdebug = require "remotedebug"
assert(rdebug.status == "debugger")

local aux = {}

function aux.frames()
	local info = {}
	local r = {}
	local level = 1
	while true do
		if not rdebug.getinfo(level, info) then
			break
		end
		table.insert(r, string.format("[%d] %s : %d", level, info.source, info.currentline))
		level = level + 1
	end
	return r
end

local table_mt = {}

local function wrap_v(v)
	local t = rdebug.type(v)
	if t == "table" then
		local obj = { __ref = v }
		return setmetatable(obj, table_mt)
	end
	return v
end

local function gen_table_text(self)
	local v = self.__ref
	local key, value
	local str = {}
	while true do
		key, value = rdebug.next(v, key)
		if key == nil then
			break
		end
		table.insert(str, string.format("%s:%s", rdebug.value(key), rdebug.value(value)))
	end
	return "{" .. table.concat(str, ",") .. "}"
end

function table_mt:__tostring()
	self.__text = self.__text or gen_table_text(self)
	return self.__text
end

function table_mt:__index(k)
	local key = k
	if type(k) == "table" then
		k = k.__ref
	end
	local v = rdebug.index(self.__ref, k)
	if v then
		v = wrap_v(v)
		self[key] = v
		return v
	end
end

local frame_mt = {}

function frame_mt:__tostring()
	return self.__text or "[frame]"
end

function frame_mt:__index(k)
	return self.locals[k] or self.upvalues[k]
end

function aux.frame(level)
	local info = rdebug.getinfo(level)
	if not info then
		return
	end
	local frame = {
		locals = {},
		upvalues = {},
	}
	local str = { "  locals: " }
	local i = -1
	while true do
		local name,v = rdebug.getlocal(level, i)
		if name == nil then
			break
		end
		table.insert(str, string.format("%s ",rdebug.value(v)))
		frame.locals[i] = wrap_v(v)
		i = i - 1
	end
	i=1
	while true do
		local name,v = rdebug.getlocal(level, i)
		if name == nil then
			break
		end
		table.insert(str, string.format("%s:%s ",name,rdebug.value(v)))

		v = wrap_v(v)
		frame.locals[i] = v
		frame.locals[name] = v
		i = i + 1
	end
	table.insert(str, "\n  upvalues: ")
	i=1
	local f = rdebug.getfunc(level)
	while true do
		local name,v = rdebug.getupvalue(f, i)
		if name == nil then
			break
		end
		table.insert(str, string.format("%s:%s ",name,rdebug.value(v)))
		v = wrap_v(v)
		frame.upvalues[i] = v
		frame.upvalues[name] = v
		i = i + 1
	end

	frame.__text = string.format("[%d] %s : %d\n", level, info.source, info.currentline) .. table.concat(str)
	return setmetatable(frame, frame_mt)
end

return aux
