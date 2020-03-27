package.path = table.concat({
    "?.lua",
	"engine/?.lua",
	"engine/?/?.lua",
}, ";")

require "runtime"
local pm = require "antpm"
pm.import "ant.imgui_editor"
