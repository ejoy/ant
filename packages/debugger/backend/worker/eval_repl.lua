local source, level = ...
level = level + 2

local f = assert(debug.getinfo(level,"f").func, "can't find function")
local uv = {}
local locals = {}
local uv_id = {}
local local_id = {}
local i = 1
while true do
	local name, value = debug.getlocal(level, i)
	if name == nil then
		break
	end
	if name:byte() ~= 40 then	-- '('
		uv[#uv+1] = name
		locals[#locals+1] = ("[%d]=%s,"):format(i,name)
		local_id[name] = value
	end
	i = i + 1
end
local i = 1
while true do
	local name = debug.getupvalue(f, i)
	if name == nil then
		break
	end
	uv_id[name] = i
	uv[#uv+1] = name
	i = i + 1
end
local full_source
if #uv > 0 then
	full_source = ([[
local $ARGS
return function(...)
$SOURCE
end,
function()
return {$LOCALS}
end
]]):gsub("%$(%w+)", {
	ARGS = table.concat(uv, ","),
	SOURCE = source,
	LOCALS = table.concat(locals),
})
else
	full_source = ([[
return function(...)
$SOURCE
end,
function()
return {$LOCALS}
end
]]):gsub("%$(%w+)", {
	SOURCE = source,
	LOCALS = table.concat(locals),
})
end

local func, update = assert(load(full_source, '=(eval)'))()
local i = 1
while true do
	local name = debug.getupvalue(func, i)
	if name == nil then
		break
	end
	local local_value = local_id[name]
	if local_value then
		debug.setupvalue(func, i, local_value)
	end
	local upvalue_id = uv_id[name]
	if upvalue_id then
		debug.upvaluejoin(func, i, f, upvalue_id)
	end
	i = i + 1
end
local rets
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
	rets = table.pack(func(table.unpack(vargs)))
else
	rets = table.pack(func())
end
local needupdate = update()
for k,v in pairs(needupdate) do
	debug.setlocal(level,k,v)
end
return table.unpack(rets)
