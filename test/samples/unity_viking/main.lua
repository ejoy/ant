package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

print = function (...)
    for i=1, select('#', ...) do
        local c = select(i, ...)
        io.stdout:write(tostring(c))
        io.stdout:write('\t')
    end

    io.stdout:write('\n')
end

require "runtime"
local pm = require "antpm"
pm.import "unity_viking"
