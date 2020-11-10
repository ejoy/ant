local LT_ALWAYS <const> = 0
local LT_ERROR <const> = 1
local LT_ASSERT <const> = 2
local LT_WARNING <const> = 3
local LT_INFO <const> = 4
local LT_DEBUG <const> = 5

local function output(type, ...)
	local t = table.pack(...)
	local s = {}
	for i = 1, t.n do
		s[#s+1] = tostring(t[i])
	end
	s = table.concat(s)
	rmlui.Log(type, s)
	print(s)
end

local m = {}

function m.error(...)
	output(LT_ERROR, ...)
end


function m.warn(...)
	output(LT_WARNING, ...)
end

function m.info(...)
	output(LT_INFO, ...)
end

function m.debug(...)
	output(LT_DEBUG, ...)
end

function m.assert(cond, ...)
	if not cond then
		output(LT_ASSERT, ...)
	end
end

function m.trace(message)
	output(LT_INFO, debug.traceback(message, 2))
end

m.log = m.info

return m
