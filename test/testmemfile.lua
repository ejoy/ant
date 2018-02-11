dofile "libs/init.lua"

local f = assert(io.open("mem://test.lua", "w"))
f:write[[
print "Hello World"
]]

f:close()

dofile "mem://test.lua"
