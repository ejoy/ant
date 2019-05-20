package.path = table.concat({
    "libs/?.lua",
    "libs/?/?.lua",
}, ";")

local cpaths = {	
    "clibs/?.dll",
	"bin/?.dll",
}

local numarg = select("#", ...)
if numarg > 0 then
	local args = {}
	for i=1, numarg do
		args[#args+1] = select(i, ...)
	end
	
	local function has_arg(name)
		for _, arg in ipairs(args) do
			if arg == name then
				return true
			end
		end
	end
	if has_arg("with-msvc") then
		table.insert(cpaths, 1, "projects/msvc/vs_bin/x64/Debug/?.dll")
	end
end

package.cpath = table.concat(cpaths, ";")

require "editor.vfs"
require "editor.init_bgfx"
require "filesystem"

require "common.log"
import_package = (require "antpm").import

local print_func = require "common.print_r"
print_r = print_func.print_r
print_a = print_func.print_a
function dprint(...) print(...) end
