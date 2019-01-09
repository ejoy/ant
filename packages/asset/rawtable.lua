local fs = require "filesystem"

return function (filepath)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end
