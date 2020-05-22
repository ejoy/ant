package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"packages/compile_resource/?.lua",
	"?.lua",
}, ";")
package.cpath = table.concat({
    "clibs/?.dll",
}, ";")

require "bootstrap"
require "fx.toolset"
require "fx.compile"
import_package "ant.shaderc"
