local rdebug = require "remotedebug"

rdebug.start "debugmain"

local function foo(...)
	print(...)	-- line 6, look debugmain.lua
end

local function foo2()
	local a = 1
	coroutine.yield()
	return a
end

local b = { a = 2 }

local function abc(a, ...)
	local a = b.a
	local a = { 1,2,3,b = { c = { d = 1 } } }
	setmetatable(a, {})

	local c = {}
	local d = { [c] = { e = 1 }, 3, a = {4,5} }

	local co = coroutine.create(foo2)
	coroutine.resume(co)

	rdebug.probe "abc"
	local c = 2
	return a, c, ...
end

for i = 1, 3 do
	rdebug.probe "ABC"
end

abc(1,2,{a = 1})

foo(5,4,3,2,1)

