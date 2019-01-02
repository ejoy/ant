local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")

package.path = table.concat({
    "engine/libs/?.lua",
    "engine/libs/?/?.lua",
    "engine/?.lua",
}, ";")

package.cpath = root .. "/" .. local_binpath .. "/?.dll;" ..
                root .. "/bin/?.dll"

assert(loadfile(root .. "/libs/vfs/require.lua"))(root)
assert(loadfile(root .. "/libs/vfs/vfspath.lua"))(root)

require "common/import"
require "common/log"

print_r = require "common/print_r"
function dprint(...) print(...) end