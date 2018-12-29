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

function util.file_is_newer(check, base)
	local rp_check = vfs.realpath(check)
	local rp_base  = vfs.realpath(base)

	local base_mode = lfs.attributes(rp_base, "mode")
	local check_mode = lfs.attributes(rp_check, "mode")

	if base_mode == nil and check_mode then
		return true
	end

	if base_mode ~= check_mode then
		return nil
	end

	local base_mtime = util.last_modify_time(base)
	local check_mtime = util.last_modify_time(check)
	return check_mtime > base_mtime
end

local timestamp_cache = {}
function util.last_modify_time(filename, use_cache)
	local realfilename = vfs.realpath(filename)
	if not use_cache then
		return lfs.attributes(realfilename, "modification")
	end
	
	if not timestamp_cache[filename] then
		local last_t = lfs.attributes(realfilename, "modification")
		timestamp_cache[filename] = last_t
	
		return last_t
	else
		return timestamp_cache[filename]
	end
	--]]
end

function util.clear_timestamp_cache(filename)
	timestamp_cache[filename] = nil
end

return util