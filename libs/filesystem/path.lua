local fs = require "lfs"
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
    local fn = name:match("[/\\]?([%w_]+)%.[%w_-]+$")
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

function path.is_absolute_path(p)
	if p:sub(1, 1) == '/' then
		return true
	end

	if p:sub(2, 2) == ":" then
		return true
	end

	return false
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

function path.create_dirs(fullpath)    
	fullpath = path.normalize(path.trim_slash(fullpath))
	if not path.is_absolute_path(fullpath) then
		fullpath = path.join(fs.currentdir(), fullpath)
	end
	local tmp
	for m in fullpath:gmatch("[^\\/]+") do        
		tmp = tmp and path.join(tmp, m) or m
		if not fs.exist(tmp) then
            fs.mkdir(tmp)
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

function path.remove(subpath)
	for name in path.dir(subpath) do	
		local fullpath = path.join(subpath, name)
		if path.isdir(fullpath) then
			path.remove(fullpath)
		else
			fs.remove(fullpath)
		end	
	end

	fs.rmdir(subpath)
end

function path.dir(subfolder, filters)
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

function path.listfiles(subfolder, files, filter_exts)	
	if not fs.exist(subfolder) then
		return
	end
	for p in path.dir(subfolder) do
		local filepath = path.join(subfolder, p)
		if path.isdir(filepath) then
			path.listfiles(filepath, files, filter_exts)
		else
			if filter_exts then
				if type(filter_exts) == "function" then
					if filter_exts(filepath) then
						table.insert(files, filepath)
					end
				else
					assert(type(filter_exts) == "table")
					local ext = path.ext(p)
					for _, e in ipairs(filter_exts) do
						if ext == e then
							table.insert(files, filepath)
						end
					end
				end

			else
				table.insert(files, filepath)
			end
		end
	end
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