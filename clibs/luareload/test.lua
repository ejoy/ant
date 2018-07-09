local reload = require "reload"
reload.postfix = "_update"	-- for test

local mymod = require "mymod"

function reload.print(...)
	print("  DEBUG:", ...)
end

mymod.foobar(42)

local tmp = {}
local foo = mymod.foo2()
tmp[foo] = foo
print("FOO before", foo)

local obj = mymod.new()

obj:show()

local geta = mymod.foo3()

print("A =", geta())

function test()
	print("BEFORE update foo", foo)
	reload.reload { "mymod" }
	print("AFTER update foo", foo)
end

test()
foo()

print("FOO after", foo)
assert(tmp[foo] == foo)
print("A*2 =", geta())

obj:show()
