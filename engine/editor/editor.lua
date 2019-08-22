
local cpaths = {	
    "clibs/?.dll",
	"bin/?.dll",
}

if #arg > 0 then
	local function has_arg(name)
		for _, a in ipairs(arg) do
			if a == name then
				return true
			end
		end
	end
	if has_arg("--bin=msvc") then
		table.insert(cpaths, 1, "projects/msvc/vs_bin/Debug/?.dll")
	end
end

package.cpath = table.concat(cpaths, ";")

require "editor.vfs"
require "common.init_bgfx"
require "common.window"
require "filesystem"

local fs = require "filesystem.local"
local vfs = require "vfs"
vfs.new(fs.path(arg[0]):remove_filename())

local pm = require "antpm"
pm.init()
import_package = pm.import

print_r 	= require "editor.print_r".print_r
dump_a 		= require "editor.print_r".dump_a
print_a 	= require "editor.print_r".print_a

log 		= require "editor.log"

