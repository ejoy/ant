local util = {}
util.__index = util

local fs = require "filesystem"

function util.write_to_file(fn, content, mode)
    local f = io.open(fn, mode or "w")
    f:write(content)
	f:close()
	return fn
end

function util.file_is_newer(check, base)
	local base_mode = fs.attributes(base, "mode")
	local check_mode = fs.attributes(check, "mode")

	if base_mode == nil and check_mode then
		return true
	end

	if base_mode ~= check_mode then
		return nil
	end

	local checktime = fs.attributes(check, "modification")
	local basetime = fs.attributes(base, "modification")
	return checktime > basetime
end

function util.read_from_file(filename)
    local f = io.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

return util