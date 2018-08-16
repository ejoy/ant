local util = {}
util.__index = util

local fs = require "filesystem"

function util.write_to_file(fn, content, mode)
    local f = io.open(fn, mode or "w")
    f:write(content)
    f:close()
end

function util.read_from_file(filename)
    local f = io.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

function util.file_is_newer(check, base)
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

function util.last_modify_time(filename)
	return fs.attributes(filename, "modification")
end

function util.dir(subfolder, filters)
	local oriiter, d, idx = fs.dir(subfolder)

	local function iter(d)
		local name = oriiter(d)
		if name == "." or name == ".." then
			return iter(d)
		end
		if filters then
			for _, f in ipairs(filters) do
				if f == name then
					return iter(d)
				end
			end
		end
		return name
	end
	return iter, d, idx
end

return util