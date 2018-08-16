local fs = require "filesystem"

local path = {}
path.__index = path


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
    local fn = name:match("[/\\]([%w_]+)%.[%w_-]+$")
    return fn
end

function path.parent(fullname)
    local path = fullname:match("(.+)[/\\][%w_.-]+$")
    return path
end

function path.normalize(fullname)
	local t = {}	
	for m in fullname:gmatch("([^/\\]+)[/\\]?") do
		if m == ".." and next(t) then
			table.remove(t, #t)
		elseif m ~= "." then
			table.insert(t, m)
		end		
	end

	return table.concat(t, "/")
end

function path.remove_filename(fullname)
	return path.parent(fullname)
end

function path.is_mem_file(name)
    return name:match("^mem://.+") ~= nil
end

function path.is_absolute_path(p)
	if p:sub(1, 1) == '/' then
		return true
	end

	if p:find(":", 1, true) then
		return true
	end

	return false
end

function path.join(...)
    local function join_ex(tb, p0, ...)
		if p0 then
			if p0 ~= "" then
				local lastchar = p0:sub(#p0)
				if lastchar == '/' or lastchar == '\\' then
					p0 = p0:sub(1, #p0 - 1)
				end
				table.insert(tb, p0)
			end
            join_ex(tb, ...)
        end
    end

    local tb = {}
    join_ex(tb, ...)
    return table.concat(tb, '/')
end

function path.trim_slash(fullpath)
    local m = fullpath:match("^%s*[/\\]*(.+)[/\\]%s*$")
    return m or fullpath
end

function path.create_dirs(fullpath)    
	fullpath = path.normalize(path.trim_slash(fullpath))

    --todo mac app is in sand box, need fix
    local cwd
    if PLATFORM == "MAC" then
        cwd = "/"
    else
        cwd = fs.currentdir()
    end
    
    for m in fullpath:gmatch("[^\\/]+") do
        cwd = path.join(cwd, m)
        if not fs.exist(cwd) then
            fs.mkdir(cwd)
        end
    end
end

function path.isdir(filepath)
	local m = fs.attributes(filepath, "mode")
	return m == "directory"
end

function path.isfile(filepath)
	local m = fs.attributes(filepath, "mode")
	return m == "file"
end

return path