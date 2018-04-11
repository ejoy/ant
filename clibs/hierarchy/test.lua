local hierarchy = require "hierarchy"

local root = hierarchy.new()

root[1] = { name = "child" }

print(root[1])

root[1].name = "foobar"

print(root[1].name)
local old = root[1]

root[2] = { name = "2" }

local new = root[2]

root[1] = nil

for i, v in ipairs(root) do
	print("===>", i,v.name)
end

print(new.name)
print(old)	-- Invalid node
print(old.name)	-- Invalid node
