local util = {}
util.__index = util

local lfs = require "lfs"
local path = require "filesystem.path"
local localfile = require "filesystem.file"

function util.exist(path)
	if lfs.exist then
		return lfs.exist(path)
	end
	return lfs.attributes(path, "mode") ~= nil
end

function util.write_to_file(fn, content, mode)
    local f = localfile.open(fn, mode or "w")
    f:write(content)
	f:close()
	return fn
end

function util.read_from_file(filename)
    local f = localfile.open(filename, "r")
    local content = f:read("a")
    f:close()
    return content
end

function util.file_is_newer(check, base)
	local base_mode = lfs.attributes(base, "mode")
	local check_mode = lfs.attributes(check, "mode")

	if base_mode == nil and check_mode then
		return true
	end

	if base_mode ~= check_mode then
		return nil
	end

	local checktime = lfs.attributes(check, "modification")
	local basetime = lfs.attributes(base, "modification")
	return checktime > basetime
end

local function create_dirs(fullpath)
	local parentpath = path.parent(fullpath)
	if not util.exist(parentpath) then
		create_dirs(parentpath)
	end
	lfs.mkdir(fullpath)
end

function util.create_dirs(fullpath)
	fullpath = path.normalize(path.trim_slash(fullpath))
	if not path.is_absolute_path(fullpath) then
		fullpath = path.join(lfs.currentdir(), fullpath)
	end
	create_dirs(fullpath)
end

function util.isdir(filepath)
	local m = lfs.attributes(filepath, "mode")
	return m == "directory"
end

function util.isfile(filepath)
	local m = lfs.attributes(filepath, "mode")
	return m == "file"
end

function util.remove(subpath)
	for name in util.dir(subpath) do
		local fullpath = path.join(subpath, name)
		if util.isdir(fullpath) then
			util.remove(fullpath)
		else
			lfs.remove(fullpath)
		end	
	end

	lfs.rmdir(subpath)
end

function util.dir(subfolder, filters)
	local oriiter, d, idx = lfs.dir(subfolder)

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

function util.listfiles(subfolder, files, filter_exts)
	if not util.exist(subfolder) then
		return
	end
	for p in util.dir(subfolder) do
		local filepath = path.join(subfolder, p)
		if util.isdir(filepath) then
			util.listfiles(filepath, files, filter_exts)
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

function util.personaldir()
	if lfs.personaldir then
		return lfs.personaldir()
	end
	return path.join(os.getenv 'HOME', 'Documents')
end

return util
