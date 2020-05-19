local function getcpath()
	if os.getenv "HOME" then
		return "clibs/?.dll"
	end

	local i = 0
	while arg[i] ~= nil do
		i = i - 1
	end
	
	local clibs = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
	local ext = "dll"

	return ("%s/?.%s"):format(clibs, ext)
end
package.cpath = getcpath()

require "editor.vfs"
require "common.init_bgfx"
require "common.window"
require "filesystem"

require "common.sort_pairs"

local fs = require "filesystem.local"
local vfs = require "vfs"
vfs.new(fs.path(arg[0]):remove_filename())

local pm = require "antpm"
pm.initialize()
import_package = pm.import
import_package "ant.asset".init()
require "editor.log"
