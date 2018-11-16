local fs = {}; fs.__index = fs

local vfs = require "vfs"
require "runtime.vfsio"
function fs.open(filename, mode)
	return io.open(filename, mode)
end

function fs.exist(filepath)
	return vfs.list(filepath) ~= nil
end

function fs.isdir(filepath)
	local item = vfs.list(filepath)
	return item and item.dir
end

function fs.isfile(filename)
	local item = vfs.list(filename)
	return item and (not item.dir)
end

return fs