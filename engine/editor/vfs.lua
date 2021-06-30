if package.loaded.vfs then
	return package.loaded.vfs
end

local _path = package.path
package.path = "engine/?.lua"
local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
package.path = _path
local vfs = require "vfs"
if _VFS_ROOT_ then
	vfs.initfunc("engine/editor/init_vfs.lua", _VFS_ROOT_)
end
local repo = vfs.repo

function vfs.virtualpath(pathname)
	return access.virtualpath(repo, pathname)
end

function vfs.list(path)
	path = path:match "^/?(.-)/?$" .. '/'
	local item = {}
	for filename in pairs(access.list_files(repo, path)) do
		local realpath = access.realpath(repo, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	return item
end

function vfs.type(filepath)
	local rp = access.realpath(repo, filepath)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function vfs.merge_mount(other)
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

return vfs
