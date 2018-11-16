local fs = {}; fs.__index = fs

local vfs = require "vfs"
require "runtime.vfsio"
function fs.open(filename, mode)
	return io.open(filename, mode)
end

function fs.exist(filepath)	
	return vfs.type(filepath) ~= nil
end

function fs.isdir(filepath)
	return vfs.type(filename) == 'dir'
end

function fs.isfile(filename)
	return vfs.type(filename) == 'file'
end

return fs