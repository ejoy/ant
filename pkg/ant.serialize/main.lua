local aio = import_package "ant.io"
local fastio = require "fastio"
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

local function load(filename)
	local basepath = filename:match "^(.-)[^/|]*$"
	return datalist.parse(aio.readall(filename), function (args)
		if args[1] == "path" then
			local path = args[2]
			if path:sub(1,1) == "/" then
				return path
			end
			return normalize(basepath .. (path:match "^%./(.+)$" or path))
		end
		return args[2]
	end)
end

local function parse(content, filename)
	local basepath = filename:match "^(.-)[^/|]*$"
	return datalist.parse(content, function (args)
		if args[1] == "path" then
			local path = args[2]
			if path:sub(1,1) == "/" then
				return path
			end
			return normalize(basepath .. (path:match "^%./(.+)$" or path))
		end
		return args[2]
	end)
end

local function default_func(args)
    return args[2]
end

local function load_lfs(filename)
	return datalist.parse(fastio.readall_f(filename), default_func)
end

local function builtin_path(v)
    return "$path "..v
end

return {
    load = load,
    load_lfs = load_lfs,
    parse = parse,
    stringify = require "stringify",
    path = builtin_path,
}
