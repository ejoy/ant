local source, level = ...
level = level + 2

if _VERSION == "Lua 5.1" then
	load = loadstring
	function table.pack(...)
		local t = {...}
		t.n = select("#", ...)
		return t
	end
	table.unpack = unpack
end

local f = assert(debug.getinfo(level,"f").func, "can't find function")
local args = {}
local local_id = {}
local local_value = {}
local upvalue_id = {}
local i = 1
while true do
	local name, value = debug.getlocal(level, i)
	if name == nil then
		break
	end
	if name:byte() ~= 40 then	-- '('
		args[#args+1] = name
		local_id[name] = i
		local_value[name] = value
	end
	i = i + 1
end
local i = 1
while true do
	local name = debug.getupvalue(f, i)
	if name == nil then
		break
	end
	args[#args+1] = name
	upvalue_id[name] = i
	i = i + 1
end
local full_source
if #args > 0 then
	full_source = ([[
local $ARGS
return function(...)
return $SOURCE
end]]):gsub("%$(%w+)", {
	ARGS = table.concat(args, ","),
	SOURCE = source,
})
else
	full_source = ([[
return function(...)
return $SOURCE
end]]):gsub("%$(%w+)", {
	SOURCE = source,
})
end
local func = assert(load(full_source, '=(eval)'))()
local i = 1
while true do
	local name = debug.getupvalue(func, i)
	if name == nil then
		break
	end
	local uvid = upvalue_id[name]
	if uvid then
		local upname, upvalue = debug.getupvalue(f, uvid)
		if upname ~= nil then
			debug.setupvalue(func, i, upvalue)
		end
	end
	if local_id[name] then
		debug.setupvalue(func, i, local_value[name])
	end
	i = i + 1
end
local vararg, v = debug.getlocal(level, -1)
if vararg then
	local vargs = { v }
	local i = 2
	while true do
		vararg, v = debug.getlocal(level, -i)
		if vararg then
			vargs[i] = v
		else
			break
		end
		i=i+1
	end
	return func(table.unpack(vargs))
else
	return func()
end
