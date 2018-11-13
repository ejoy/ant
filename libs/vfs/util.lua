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
	return fs.attributes(realpath, which)
end

local function replace_path(srcpath, checkpath, rplpath)
	local config = require "common.config"

	local p0 = srcpath:gsub('\\', '/')
	
	local platform = config.platform()
	if platform == "Windows" then
		local realpath_lower = checkpath:lower()
		local p0_lower = p0:lower()
		local pos = p0_lower:find(realpath_lower) 
		if pos then
			return rplpath .. p0:sub(#realpath_lower + 1), true
		end
		return srcpath, false
	else
		local s, c = p0:gsub(checkpath, rplpath)
		return s, c ~= 0
	end	
end

function util.convert_to_mount_path(p, mountpath)	
	local mount_realpath = vfs.realpath(mountpath):gsub('\\', '/')
	local rpl = replace_path(p, mount_realpath, mountpath)
	return rpl	
end

function util.filter_abs_path(abspath)
	local assetfolder = (fs.currentdir() .. "/assets"):gsub("\\", "/")

	local newpath, found = replace_path(abspath, assetfolder, "assets")
	if not found then
		return util.convert_to_mount_path(abspath, "engine/assets")
	end

	return newpath
end

function util.file_is_newer(check, base)
	local rp_check = vfs.realpath(check)
	local rp_base  = vfs.realpath(base)

	local base_mode = fs.attributes(rp_base, "mode")
	local check_mode = fs.attributes(rp_check, "mode")

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
		return fs.attributes(realfilename, "modification")
	end
	
	if not timestamp_cache[filename] then
		local last_t = fs.attributes(realfilename, "modification")
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