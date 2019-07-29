local thread = require "thread"

local d = { x=1,y=2,z=3,ref = {} }
d[0] = d
d.ref[0] = d.ref
local s = thread.pack(d)
local u = thread.unpack(s)

print(u)
for k,v in pairs(u) do
	print(k,v)
end
print(u.ref[0])
