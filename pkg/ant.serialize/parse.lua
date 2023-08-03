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

return function (basepath, data)
	if basepath then
		basepath = basepath:match "^(.-)[^/|]*$"
		return datalist.parse(data, function (args)
			if args[1] == "path" then
				local path = args[2]
				if path:sub(1,1) == "/" then
					return path
				end
				return normalize(basepath .. (path:match "^%./(.+)$" or path))
			end
			return args[2]
		end)
	else
		return datalist.parse(data, function (args)
			return args[2]
		end)
	end
end
