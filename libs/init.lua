-- dofile this file first to init env

local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")
from_msvc = os.getenv "MSVC"

package.cpath = root .. "/" .. local_binpath .. "/?.dll;" .. 
                root .. "/bin/?.dll"

package.path = root .. "/libs/?.lua;" .. root .. "/libs/?/?.lua"

require "common/import"
require "common/log"

print_r = require "common/print_r"
require "filesystem"
