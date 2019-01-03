local fs = {}; fs.__index = fs

local vfs = require "vfs"
require "runtime.vfsio"
function fs.open(filepath, mode)
	return io.open(filepath:string(), mode)
end

function fs.exist(filepath)	
	return vfs.type(filepath:string()) ~= nil
end

function fs.isdir(filepath)
	return vfs.type(filepath:string()) == 'dir'
end

function fs.isfile(filepath)
	return vfs.type(filepath:string()) == 'file'
end

return fs
