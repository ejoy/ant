package.path = table.concat({
    "libs/?.lua",
    "libs/?/?.lua",
}, ";")

local cpaths = {
	"projects/msvc/vs_bin/x64/Debug/?.dll",
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

class = require "common.class"
