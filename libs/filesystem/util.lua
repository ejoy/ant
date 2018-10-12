local util = {}
util.__index = util

local fs = require "filesystem"

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

function util.file_is_newer(check, base)
	if not fs.exist(base) and fs.exist(check) then
		return true
	end

	local base_mode = fs.attributes(base, "mode")
	local check_mode = fs.attributes(check, "mode")

	if base_mode ~= check_mode then
		return nil
	end

	local base_mtime = util.last_modify_time(base)
	local check_mtime = util.last_modify_time(check)

--todo file is on server
    if not base_mtime or not check_mtime then
        return true
    end

	return check_mtime > base_mtime
end

local timestamp_cache = {}
function util.last_modify_time(filename, use_cache)
	if not use_cache then
		return fs.attributes(filename, "modification")
	end
	
	if not timestamp_cache[filename] then
		local last_t = fs.attributes(filename, "modification")
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