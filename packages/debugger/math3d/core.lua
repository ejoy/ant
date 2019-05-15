local self, dbgName = ...

if not package.loaded[dbgName] then
	return self
end

local mt = debug.getmetatable(self)
local mscall = mt.__call
local ms = function(...) return mscall(self, ...) end
local _, upvalue1 = debug.getupvalue(mt.__call, 1)

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
				code[#code+1] = ('[%s]  %s'):format(op, operator[op] or 'unknown operator')
			end
		elseif type(arg) == 'function' then
			code[#code+1] = 'unknown operator'
		else
			local t = ms(arg, 'T')
			code[#code+1] = 'push ' .. stringify(t)
		end
	end
	return table.concat(code, '\n') .. '\n'
end

local function to_scope(_, m)
	if m.type == 'mat' then
		return {
			type = m.type,
			{m[ 1], m[ 2], m[ 3], m[ 4]},
			{m[ 5], m[ 6], m[ 7], m[ 8]},
			{m[ 9], m[10], m[11], m[12]},
			{m[13], m[14], m[15], m[16]},
		}
	end
	if m.type == 'euler' then
		return {
			type = m.type,
			x = math.deg(m[1]),
			y = math.deg(m[2]),
			z = math.deg(m[3]),
			value = {m[1],m[2],m[3]},
		}
	end
	if m.type == 'quat' then
		local r = math.acos(m[4])
		local tmp = 1.0 - m[4] * m[4]
		local axis
		if tmp > 0 then
			tmp = 1.0 / math.sqrt(tmp)
			axis = {m[1]*tmp, m[2]*tmp, m[3]*tmp}
		else
			axis = {0,0,1}
		end
		return {
			type = m.type,
			value = {m[1], m[2], m[3], m[4]},
			axis = axis,
			radian = r*2,
			angle = math.deg(r*2)
		}
	end
	return m
end

local function to_value(_, m)
	if m.type == 'mat' then
		return {
			type = m.type,
			m[1][1], m[1][2], m[1][3], m[1][4],
			m[2][1], m[2][2], m[2][3], m[2][4],
			m[3][1], m[3][2], m[3][3], m[3][4],
			m[4][1], m[4][2], m[4][3], m[4][4],
		}
	end
	if m.type == 'euler' then
		return {
			type = m.type,
			m.value[1], m.value[2], m.value[3]
		}
	end
	if m.type == 'quat' then
		return {
			type = m.type,
			m.value[1], m.value[2], m.value[3], m.value[4],
		}
	end
	return m
end

local function value_to_scope(ms, scope, value)
	for i, v in ipairs(value) do
		scope[i] = to_scope(ms, ms(v, 'T'))
	end
end

local function scope_to_value(ms, scope, value)
	for i, v in ipairs(scope) do
		if type(value[i]) == 'userdata' then
			ms(value[i], to_value(ms, v), '=')
		else
			value[i] = to_value(ms, v)
		end
	end
end

local function event_line(ms, ok, status, stack, rets)
	status.scope[1].value = {}
	status.scope[2].value = {}
	value_to_scope(ms, status.scope[1].value, stack)
	value_to_scope(ms, status.scope[2].value, rets)
	status.currentline = status.currentline + 1
	if ok then
		vscdbg:event('line', status.currentline, status.scope)
	end
	scope_to_value(ms, status.scope[1].value, stack)
	scope_to_value(ms, status.scope[2].value, rets)
end

function mt:__call(...)
	local _ = upvalue1
	local args = table.pack(...)
	local stack = reverse(ms('@'))
	local pop = {}
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
	local ok = vscdbg:event('call', compile(ms, args), '<math3d>')

	local function do_command(c)
		if c == 'm' then
			stack[#stack+1] = 'T'
			pop[#rets+1] = c
		elseif c == 'P' then
			stack[#stack+1] = 'T'
			pop[#rets+1] = c
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
				event_line(ms, ok, status, stack, rets)
				do_command(arg:sub(j,j))
			end
		else
			event_line(ms, ok, status, stack, rets)
			do_command(arg)
		end
	end
	event_line(ms, ok, status, stack, rets)
	vscdbg:event('return')
	if stack.n ~= 0 then
		ms(table.unpack(stack))
	end
	for i, c in pairs(pop) do
		rets[i] = ms(rets[i], c)
	end
	return table.unpack(rets)
end

return self
