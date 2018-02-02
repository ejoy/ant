local rdebug = require "remotedebug"

if not pcall(rdebug.start, "debugsocket") then
	print "debugger disable"
end

local function foo(a,b)
 -- look debugsocket.lua
	local c = a + b
	return c
end

local s = 0
for i=1,10 do
	s = foo(i,s)
	s = s + 1
end