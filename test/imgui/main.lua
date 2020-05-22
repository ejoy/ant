package.path = table.concat({
    "?.lua",
	"engine/?.lua",
	"engine/?/?.lua",
}, ";")

require "bootstrap"
import_package "ant.imgui_editor"
