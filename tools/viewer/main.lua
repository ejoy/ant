package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

require "bootstrap"
import_package "tools.viewer.editor"
