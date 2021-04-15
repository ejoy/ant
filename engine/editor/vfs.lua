local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

local repo

function localvfs.realpath(pathname)
	local rp = access.realpath(repo, pathname)
	return rp:string()
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
