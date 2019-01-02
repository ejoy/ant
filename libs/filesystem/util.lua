local util = {}
util.__index = util

local lfs = require "lfs"

local function create_dirs(fullpath)
	local parentpath = path.parent(fullpath)
	if not util.exist(parentpath) then
		create_dirs(parentpath)
	end
	lfs.mkdir(fullpath)
end

function util.create_dirs(fullpath)
	fullpath = path.normalize(path.trim_slash(fullpath))
	if not path.is_absolute_path(fullpath) then
		fullpath = path.join(lfs.currentdir(), fullpath)
	end
	create_dirs(fullpath)
end

function util.isdir(filepath)
	local m = lfs.attributes(filepath, "mode")
	return m == "directory"
end

function util.isfile(filepath)
	local m = lfs.attributes(filepath, "mode")
	return m == "file"
end

return util
