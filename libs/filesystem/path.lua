local path = {}
path.__index = path

local function sep(c)
	return c == '/' or c == '\\'
end

local function rootdir(fullname)
	if fullname:sub(1, 1) == '/' then
		return 2
	end
	local pos = fullname:find(':', 1, true)
	if pos then
		if sep(fullname:sub(pos + 1, pos + 1)) then
			if sep(fullname:sub(pos + 2, pos + 2)) then
				return pos + 3
			end
			return pos + 2
		end
		return pos + 1
	end
end

function path.remove_ext(name)
    local path, ext = name:match("(.+)%.([%w_-]+)$")
    if ext ~= nil then
        return path
    end

    return name
end

function path.ext(name)
    local ext = name:match(".+%.([%w_-]+)$")
    return ext
end

function path.replace_ext(name, ext)
    local pp = path.remove_ext(name)    
    if ext:sub(1, 1) ~= '.' then
        pp = pp .. '.'
    end

    return pp .. ext
end

function path.has_parent(pp)
    return pp:match("^[%w_.-]+$") == nil
end

function path.filename(name)
    return name:match("[/\\]?([%w_.-]+)$")
end

function path.filename_without_ext(name)
    local fn = name:match("[/\\]?([%w_]+)%.[%w_-]+$")
    return fn
end

function path.parent(fullname)
    local path = fullname:match("(.+)[/\\][%w_.-]+$")
    return path
end

function path.normalize(fullname)
	local pos = rootdir(fullname)
	local rootpath, otherpath
	if pos then
		rootpath, otherpath = fullname:sub(1, pos-1), fullname:sub(pos)
	else
		rootpath, otherpath = '', fullname
	end
	local t = {}
	for m in otherpath:gmatch("([^/\\]+)[/\\]?") do
		if m == ".." and next(t) then
			table.remove(t, #t)
		elseif m ~= "." then
			table.insert(t, m)
		end
	end

	return rootpath .. table.concat(t, "/")
end

function path.remove_filename(fullname)
	return path.parent(fullname)
end

function path.is_absolute_path(p)
	return rootdir(p) ~= nil
end

function path.join(p0, ...)    
	if p0 then
		if p0 ~= "" then
			p0 = p0:gsub("(.-)[\\/]?$", "%1")
		end
		local rest = path.join(...)
		if rest then
			return p0 .. '/' .. rest
		end		
	end
	return p0
end

function path.trim_slash(fullpath)
    local m = fullpath:match("^%s*[/\\]*(.+)[/\\]%s*$")
    return m or fullpath
end

function path.replace_path(srcpath, checkpath, rplpath)
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

return path