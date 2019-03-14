package.path = table.concat({
	"engine/libs/?.lua",
	"engine/libs/?/?.lua",
	"?.lua",
}, ";")

require "runtime"
local pm = require "antpm"
pm.import(pm.register("entry"))
