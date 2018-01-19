-- dofile this file first to init env

local root = os.getenv "ANTGE" or "."

package.cpath = root .. "/bin/?.dll"
package.path = root .. "/libs/?.lua;" .. root .. "/libs/?/?.lua"

require "common/import"
require "common/log"


