local datalist = require "datalist"

local function normalize_path(fullname)
    local first = (fullname:sub(1, 1) == "/") and "/" or ""
    local last = (fullname:sub(-1, -1) == "/") and "/" or ""
	local t = {}
	for m in fullname:gmatch("([^/]+)[/]?") do
		if m == ".." and next(t) then
			table.remove(t, #t)
		elseif m ~= "." then
			table.insert(t, m)
		end
	end
	return first .. table.concat(t, "/") .. last
end

local function normalize(fullname)
    local t = {}
	for m in fullname:gmatch "([^|]+)" do
        t[#t+1] = normalize_path(m)
	end
    return table.concat(t, "|")
end

local function absolute_path(base, path)
	if path:sub(1,1) == "/" or not base then
		return path
	end
    base = base:match "^(.-)[^/|]*$"
	return normalize(base .. (path:match "^%./(.+)$" or path))
end

return function (basepath, data)
    local function convert(args)
        if args[1] == "path" then
            local res = absolute_path(basepath, args[2])
            return res
        end
        return args[2]
    end
    return datalist.parse(data, convert)
end
