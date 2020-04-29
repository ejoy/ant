local rt = {}; rt.__index = rt
local fs = require "filesystem"
local fs_util = require "fs_util"

function rt.datalist(filepath)
    return fs_util.datalist(fs, filepath)
end

function rt.raw_table(filepath, fetchresult)
	return fs_util.raw_table(fs, filepath, fetchresult)
end

function rt.read_file(filepath)
    return fs_util.read_file(fs, filepath)
end

return rt