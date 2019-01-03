local util = {}; util.__index = {}
local fs = require "filesystem"
local platform = require "platform"
local OS = platform.OS

local vfs = require "vfs"

function util.replace_path(srcpath, checkpath, rplpath)
	local config = require "common.config"

	if OS == "Windows" then
		local realpath_lower = checkpath:string():lower()
		local srcpath_lower = srcpath:string():lower()
		local pos = srcpath_lower:find(realpath_lower) 
		if pos then
			return rplpath / srcpath:sub(#realpath_lower + 1), true
		end
		return srcpath, false
	else
		local s, c = srcpath:string():gsub(checkpath, rplpath)
		return fs.path(s), c ~= 0
	end
end

function util.convert_to_mount_path(p, mountpath)
	local mount_realpath = vfs.realpath(mountpath):gsub('\\', '/')
	local rpl = util.replace_path(p, mount_realpath, mountpath)
	return rpl
end

function util.filter_abs_path(abspath)
	local cwd = fs.current_path()

	local newpath, found = util.replace_path(abspath, fs.path(cwd:string() .. "/"), "")
	if not found then
		return util.convert_to_mount_path(abspath, fs.path("engine/assets")), "engine"
	end

	return newpath, "local"
end

return util