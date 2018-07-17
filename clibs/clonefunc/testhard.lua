local hardreload = require "hardreload"
require = hardreload.require

function hardreload.print(...)
	print(" DEBUG", ...)
end

local a = require "hardmod"
local foo = a.foo

print(a.foo())
print(a.foo())
print(a.foo())

print(hardreload.reload("hardmod" , "hardmod_update"))

print(foo())
print(foo())
print(foo())

print(hardreload.reload("hardmod" , "hardmod_update2"))

print(foo())
print(foo())
print(foo())


