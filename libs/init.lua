local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")

package.cpath = root .. "/" .. local_binpath .. "/?.dll;" .. 
                root .. "/bin/?.dll"

local initfile = root .. "/libs/vfs/vfspath.lua"
local f, err = loadfile(initfile)
if err then
	error(string.format("load %s failed, error:%s", initfile, err))
end
f(root)

require "common/import"
require "common/log"

print_r = require "common/print_r"
function dprint(...) print(...) end