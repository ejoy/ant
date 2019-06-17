package.path = table.concat({
    "libs/?.lua",
    "libs/?/?.lua",
}, ";")

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
		table.insert(cpaths, 1, "projects/msvc/vs_bin/x64/Debug/?.dll")
	end
end

package.cpath = table.concat(cpaths, ";")

require "editor.vfs"
require "editor.init_bgfx"
require "filesystem"
import_package = (require "antpm").import
