local ms, dbgName = ...

if not package.loaded[dbgName] then
	return ms
end

local vscdbg = require(dbgName)
local math3d = require "math3d"
local operator = math3d.cmd_description()

local function reverse(t)
	for i = 1, #t // 2 do
		local tmp = t[i]
		t[i] = t[#t+1-i]
		t[#t+1-i] = tmp
	end
	return t
end

local function stringify(t)
	if t.type == 'mat' then
		return 'matrix {}'
	elseif t.type == 'v4' then
		return 'vector {}'
	elseif t.type == 'quat' then
		return 'quaternion {}'
	elseif t.type == 'num' then
		return 'number {}'
	elseif t.type == 'euler' then
		return 'euler {}'
	else
		return ('unknown(%s) {}'):format(t.type)
	end
end

local function compile(ms, args)
	local code = {}
	for i = 1, args.n do
		local arg = args[i]
		if type(arg) == 'string' then
			for j = 1, #arg do
				local op = arg:sub(j,j)
				code[#code+1] = ('[%s]  %s'):format(op , operator[op] or 'unknown operator')
			end
		else
			local t = ms(arg, 'T')
			code[#code+1] = 'push ' .. stringify(t)
		end
	end
	return table.concat(code, '\n') .. '\n'
end

local function mat_1to2(ms, m)
	if m.type ~= 'mat' then
		return m
	end
	return {
		type = m.type,
		{m[ 1], m[ 2], m[ 3], m[ 4]},
		{m[ 5], m[ 6], m[ 7], m[ 8]},
		{m[ 9], m[10], m[11], m[12]},
		{m[13], m[14], m[15], m[16]},
	}
end

local function mat_2to1(ms, m)
	if m.type ~= 'mat' then
		return m
	end
	return {
		type = m.type,
		m[1][1], m[1][2], m[1][3], m[1][4],
		m[2][1], m[2][2], m[2][3], m[2][4],
		m[3][1], m[3][2], m[3][3], m[3][4],
		m[4][1], m[4][2], m[4][3], m[4][4],
	}
end

local function value_to_scope(ms, scope, value)
	for i, v in ipairs(value) do
		scope[i] = mat_1to2(ms, ms(v, 'T'))
	end
end

local function scope_to_value(ms, scope, value)
	for i, v in ipairs(scope) do
		if type(value[i]) == 'userdata' then
			ms(value[i], mat_2to1(ms, v), '=')
		else
			value[i] = mat_2to1(ms, v)
		end
	end
end

local function event_line(ms, status, stack, rets)
	status.scope[1].value = {}
	status.scope[2].value = {}
	value_to_scope(ms, status.scope[1].value, stack)
	value_to_scope(ms, status.scope[2].value, rets)
	status.currentline = status.currentline + 1
	vscdbg:event('line', status.currentline, status.scope)
	scope_to_value(ms, status.scope[1].value, stack)
	scope_to_value(ms, status.scope[2].value, rets)
end

local _, upvalue1 = debug.getupvalue(ms, 1)

return function (...)
	local _ = upvalue1
	local args = table.pack(...)
	local stack = reverse(ms('@'))
	local m = {}
	local rets = {}
	local status = {
		currentline = 0,
		scope = {
			{
				name = 'Stack',
				value = {},
			}, 
			{
				name = 'Return';
				value = {},
			}
		}
	}
	vscdbg:event('call', compile(ms, args), '<math3d>')

	local function do_command(c)
		if c == 'm' then
			stack[#stack+1] = 'T'
			m[#rets+1] = true
		else
			stack[#stack+1] = c
		end
		stack[#stack+1] = '@'
		local t = table.pack(ms(table.unpack(stack)))
		for i = 1, #t - 1 do
			rets[#rets+1] = t[i]
		end
		stack = reverse(t[#t])
	end
	for i = 1, args.n do
		local arg = args[i]
		if type(arg) == 'string' then
			for j = 1, #arg do
				event_line(ms, status, stack, rets)
				do_command(arg:sub(j,j))
			end
		else
			event_line(ms, status, stack, rets)
			do_command(arg)
		end
	end
	event_line(ms, status, stack, rets)
	vscdbg:event('return')
	if stack.n ~= 0 then
		ms(table.unpack(stack))
	end
	for i in pairs(m) do
		rets[i] = ms(rets[i], 'm')
	end
	return table.unpack(rets)
end
