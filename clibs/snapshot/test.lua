local snapshot = require "snapshot"
local S1 = snapshot()
local f = assert(io.open('test.txt', 'w'))
for k,v in pairs(S1) do
	f:write('---'..tostring(k):sub(11)..'---\n')
	f:write(v)
	f:write('\n')
end
f:close()
