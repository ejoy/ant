local util = {}; util.__index = {}

local vfs = require "vfs"
function util.open(filename, mode)
	if mode:find("w") then
		return io.open(filename, mode)
	else
		local realpath = vfs.realpath(filename)
		return io.open(realpath, mode)
	end
end

local fs = require "filesystem"
function util.exist(filename)
	local realpath = vfs.realpath(filename)
	return fs.exist(realpath)
end

function util.attributes(filename, which)
	local realpath = vfs.realpath(filename)
	return fs.attributes(filename, which)
end


return util