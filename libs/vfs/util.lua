local util = {}; util.__index = {}
local path = require "filesystem.path"
local vfs = require "vfs"
function util.convert_to_mount_path(p, mountpath)
	local mount_realpath = vfs.realpath(mountpath):gsub('\\', '/')
	local rpl = path.replace_path(p, mount_realpath, mountpath)
	return rpl
end

local lfs = require "lfs"
function util.filter_abs_path(abspath)
	local assetfolder = lfs.currentdir():gsub("\\", "/")

	local newpath, found = path.replace_path(abspath, assetfolder .. "/", "")
	if not found then
		return util.convert_to_mount_path(abspath, "engine/assets"), "engine"
	end

	return newpath, "local"
end

return util