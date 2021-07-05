if package.loaded.vfs then
	return package.loaded.vfs
end

local vfs = require "vfs"
return vfs
