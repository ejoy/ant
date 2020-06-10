local u = {}

local fs = require "filesystem.local"
local datalist = require "datalist"

function u.datalist(filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

function u.write_file(filepath, c)
    local f = fs.open(filepath, "wb")
    f:write(c)
    f:close()
end

return u
