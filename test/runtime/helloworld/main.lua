package.path = table.concat({
	"engine/libs/?.lua",
	"engine/libs/?/?.lua",
}, ";")

local rt = require "runtime"

print "Hello,World!"

rt.start({}, {})
