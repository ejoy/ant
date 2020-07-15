package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

require "bootstrap"
require "vfs.repo"
import_package "ant.fileserver"
