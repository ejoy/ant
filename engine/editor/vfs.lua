local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

local repo

function localvfs.realpath(pathname)
	local rp = access.realpath(repo, pathname)
	return rp:string()
end

function localvfs.list(path)
	path = path:match "^/?(.-)/?$"
	local files = access.list_files(repo, path)
	path = path .. '/'
	local item = {}
	for filename in pairs(files) do
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
	local mountpoint = access.readmount(rootpath / ".mount")
	local mountname = access.mountname(mountpoint)
	repo = {
		_mountname = mountname,
		_mountpoint = mountpoint,
		_root = rootpath,
	}
end

function localvfs.repo()
	return repo
end

package.loaded.vfs = localvfs
