local ms, dbgName = ...

if not package.loaded[dbgName] then
	return ms
end

local vscdbg = require(dbgName)

local function reverse(t)
	for i = 1, #t // 2 do
		local tmp = t[i]
		t[i] = t[#t+1-i]
		t[#t+1-i] = tmp
	end
	return t
end

local operator = {
	['P'] = "pop as id",
	['m'] = "pop as pointer",
	['T'] = "pop as table",
	['V'] = "top as string",
	['='] = "assign to ref",
	['1'] = "dup 1",
	['2'] = "dup 2",
	['3'] = "dup 3",
	['4'] = "dup 4",
	['5'] = "dup 5",
	['6'] = "dup 6",
	['7'] = "dup 7",
	['8'] = "dup 8",
	['9'] = "dup 9",
	['S'] = "swap",
	['R'] = "remove",
	['.'] = "dot",
	['x'] = "cross",
	['*'] = "mul",
	['%'] = "mulH",
	['n'] = "normalize",
	['t'] = "transposed",
	['i'] = "inverted",
	['-'] = "sub",
	['+'] = "add",
	['l'] = "look at",
	['L'] = "look from",
	['>'] = "extract",
	['e'] = "to euler",
	['q'] = "to quaternion",
	['d'] = "to rotation",
	['D'] = "to direction",
	['~'] = "to srt",
	['b'] = "split srt matrix to s r t",
	['@'] = "pop everything",
}

local function stringify(t)
	if t.type == 0 then
		return ('matrix {{%f,%f,%f,%f},{%f,%f,%f,%f},{%f,%f,%f,%f},{%f,%f,%f,%f}}'):format(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16])
	elseif t.type == 1 then
		return ('vector {%f,%f,%f,%f}'):format(t[1], t[2], t[3], t[4])
	elseif t.type == 2 then
		return ('quaternion {%f,%f,%f,%f}'):format(t[1], t[2], t[3], t[4])
	elseif t.type == 3 then
		return ('number {%f}'):format(t[1])
	elseif t.type == 4 then
		return ('euler {%f,%f,%f}'):format(t[1], t[2], t[3])
	else
		return ('unknown {type=%d}'):format(t.type)
	end
end

local function stringify_simple(t)
	if t.type == 0 then
		return 'matrix {}'
	elseif t.type == 1 then
		return 'vector {}'
	elseif t.type == 2 then
		return 'quaternion {}'
	elseif t.type == 3 then
		return 'number {}'
	elseif t.type == 4 then
		return 'euler {}'
	else
		return ('unknown {type=%d}'):format(t.type)
	end
end

local function compile(ms, args)
	local code = {}
	for i = 1, args.n do
		local arg = args[i]
		if type(arg) == 'string' then
			for j = 1, #arg do
				local op = arg:sub(j,j)
				code[#code+1] = ('%s (%s)'):format(op , operator[op] or 'unknown operator')
			end
		else
			local t = ms(arg, 'T')
			code[#code+1] = 'push ' .. stringify_simple(t)
		end
	end
	return table.concat(code, '\n') .. '\n'
end

local function value_to_scope(ms, scope, value)
	for i, v in ipairs(value) do
		scope[i] = ms(v, 'T')
	end
end

local function scope_to_value(ms, scope, value)
	for i, v in ipairs(scope) do
		if type(value[i]) == 'userdata' then
			ms(value[i], v, '=')
		else
			value[i] = v
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
