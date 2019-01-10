package.path = table.concat({
    "engine/libs/?.lua",
    "engine/libs/?/?.lua",
    "engine/?.lua",
}, ";")

package.cpath = table.concat({
	"projects/msvc/vs_bin/x64/Debug/?.dll",
    "clibs/?.dll",
	"bin/?.dll",
}, ";")

dofile "libs/editor/require.lua"
require "editor.vfs"
require "editor.vfspath"

require "common.log"
import_package = (require "antpm").import

-- TODO
require "fileconvert.util"

print_r = require "common.print_r"
function dprint(...) print(...) end
