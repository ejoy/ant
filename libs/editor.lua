package.path = table.concat({
    "engine/libs/?.lua",
    "engine/libs/?/?.lua",
    "engine/?.lua",
}, ";")

package.cpath = table.concat({
    "clibs/?.dll",
    "bin/?.dll",
}, ";")

dofile "libs/editor/require.lua"
require "editor.vfs"
require "editor.vfspath"

require "common.log"
import_package = (require "antpm").import

-- TODO
require "ecs"
require "test.samples.PVPScene.PVPSceneLoader"
require "fileconvert.util"

print_r = require "common.print_r"
function dprint(...) print(...) end
