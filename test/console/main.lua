package.path = "/engine/?.lua"
require "bootstrap"

print "Hello World"

local arg = ...
-- ... is command line args
for k, v in ipairs(arg) do
	print(k,v)
end
