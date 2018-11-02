local require = import and import(...) or require
local io = require "io"
local vfsutil = require "vfs.util"

return function (filename)
	local f = vfsutil.open(filename,"rb")
	local data = f:read "a"
	f:close()
	local env = {}
	local f = assert(load (data, "@" .. filename, "bt", env))
	f()
	return env
end
