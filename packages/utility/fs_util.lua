local util = {}; util.__index = util
local datalist = require "datalist"

function util.datalist(fs, filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

function util.raw_table(fs, filepath, fetchresult)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	local result = r()
	if fetchresult then
		return result
	end
	return env
end

function util.read_file(fs, filepath)
    local f = fs.open(filepath, "rb")
    local c = f:read "a"
    f:close()
    return c
end

return util