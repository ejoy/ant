-- dofile this file first to init env

local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")

local function check_enable_pack()
	local env_ENABLE_PACK = os.getenv "ENABLE_PACK"
	if env_ENABLE_PACK == nil then
		return true
	end

	return env_ENABLE_PACK == "ON"
end

enable_pack = check_enable_pack()

package.cpath = root .. "/" .. local_binpath .. "/?.dll;" .. 
                root .. "/bin/?.dll"

package.path = root .. "/libs/?.lua;" .. root .. "/libs/?/?.lua"

require "common/import"
require "common/log"

print_r = require "common/print_r"
require "filesystem"

function dprint(...) print(...) end
