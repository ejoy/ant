package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

require "runtime"
local pm = require "antpm"
pm.import "ant.antpack"
