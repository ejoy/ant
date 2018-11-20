local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")

package.cpath = root .. "/" .. local_binpath .. "/?.dll;" .. 
                root .. "/bin/?.dll"

local f, err = loadfile "libs/vfs/vfspath.lua"
if err then
	error(string.format("load libs/vfs/vfspath.lua failed, error:%s", err))
end
f(root)

require "common/import"
require "common/log"

print_r = require "common/print_r"
function dprint(...) print(...) end