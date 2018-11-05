local util = {}
util.__index = util

local fs = require "filesystem"
local vfs = require "vfs"
local vfsutil = require "vfs.util"

function util.write_to_file(fn, content, mode)
    local f = io.open(fn, mode or "w")
    f:write(content)
	f:close()
	return fn
end

function util.read_from_file(filename)
    local f = io.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

function util.convert_to_mount_path(p, mountpath)	
	local realpath = vfs.realpath(mountpath)
	realpath = realpath:gsub('\\', '/')
	local p0 = p:gsub('\\', '/')
	return p0:gsub(realpath, mountpath)
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