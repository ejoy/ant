dofile "libs/init.lua"

local seri = import_package "ant.serialize"

local f = assert(io.open("mem://test.lua", "w"))
f:write[[
print "Hello World"
]]

f:close()

dofile "mem://test.lua"

seri.save("mem://test.lua", { x=1,y=2 })
local t = seri.load "mem://test.lua"

for k,v in pairs(t) do
	print(k,v)
end