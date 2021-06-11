local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

local repo
local io_open = io.open

function localvfs.realpath(pathname)
	local rp = access.realpath(repo, pathname)
	return rp:string()
end

local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end

function localvfs.openfile(filename)
    local real_filename = localvfs.realpath(filename)
    if not real_filename then
        return nil, ('%s:No such file or directory.'):format(filename)
    end
    local f, err, ec = io_open(real_filename, 'rb')
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end

function localvfs.loadfile(path)
    local f, err = localvfs.openfile(path)
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@/' .. path)
end

function localvfs.dofile(path)
    local f, err = localvfs.loadfile(path)
    if not f then
        error(err)
    end
    return f()
end

function localvfs.virtualpath(pathname)
	return access.virtualpath(repo, pathname)
end

function localvfs.list(path)
	path = path:match "^/?(.-)/?$" .. '/'
	local item = {}
	for filename in pairs(access.list_files(repo, path)) do
		local realpath = access.realpath(repo, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	return item
end

function localvfs.type(filepath)
	local rp = access.realpath(repo, filepath)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function localvfs.new(rootpath)
	if not lfs.is_directory(rootpath) then
		return nil, "Not a dir"
	end
	repo = {
		_root = rootpath,
	}
	access.readmount(repo)
end

function localvfs.merge_mount(other)
	if other._mountname then
		for _, name in ipairs(other._mountname) do
			if not repo._mountpoint[name] then
				repo._mountpoint[name] = other._mountpoint[name]
				repo._mountname[#repo._mountname+1] = name
			end
		end
	end
	return repo
end

if _VFS_ROOT_ then
	localvfs.new(lfs.absolute(lfs.path(_VFS_ROOT_)))
else
	localvfs.new(lfs.absolute(lfs.path(arg[0])):remove_filename())
end

package.loaded.vfs = localvfs
