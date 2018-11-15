--luacheck: globals import
local require = import and import(...) or require
local vfs_fs = require "vfs.fs"

return function (filename)
	local f = vfs_fs.open(filename,"rb")
	local data = f:read "a"
	f:close()
	local env = {}
	local r = assert(load (data, "@" .. filename, "bt", env))
	r()
	return env
end
