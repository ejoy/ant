local require = import and import(...) or require
local vfsutil = require "vfs.util"

return function (filename)
	local f = vfsutil.open(filename,"rb")
	local data = f:read "a"
	f:close()
	local env = {}
	local r = assert(load (data, "@" .. filename, "bt", env))
	r()
	return env
end
