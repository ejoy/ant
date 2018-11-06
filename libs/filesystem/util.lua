local util = {}
util.__index = util

local fs = require "filesystem"
local vfs = require "vfs"
function util.write_to_file(fn, content, mode)
    local f = io.open(fn, mode or "w")
    f:write(content)
	f:close()
	return fn
end

function util.read_from_file(filename)
    local f = io.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

return util