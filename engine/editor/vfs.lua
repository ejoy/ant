local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
local repo = require "vfs.repo"

local self

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local ext = rp:extension():string():lower()
	if self._link[ext] then
		pathname = pathname:match "^/?(.-)/?$"
		local realpath = access.link_loc(self, pathname)
		if realpath == nil then
			error(string.format("build from path failed, pathname:%s, log file can found in log folder", pathname))
		end
		return realpath:string()
	end
	return rp:string()
end

function localvfs.list(path)
	path = path:match "^/?(.-)/?$"
	local files = access.list_files(self, path)
	path = path .. '/'
	local item = {}
	for filename in pairs(files) do
		local realpath = access.realpath(self, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	return item
end

function localvfs.type(filepath)
	local rp = access.realpath(self, filepath)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function localvfs.identity(ext, identity, linkconfig)
	self._link[ext] = {identity=identity, linkconfig=linkconfig}
end

function localvfs.new(path)
	self = assert(repo.new(path))
	self:clean()
end

function localvfs.clean_build(srcpath)
	if srcpath == nil then
		self:clean()
		return
	end
	access.clean_build(self, srcpath)
end

function localvfs.add_mount(name, mountpath)
	local mnames = self._mountname
	for _, n in ipairs(mnames) do
		if n == name then
			return 
		end
	end
	if not lfs.is_directory(mountpath) then
		return
	end
	table.insert(mnames, name)
	table.sort(mnames, function(a, b) return a>b end)
	self._mountpoint[name] = mountpath
	return true
end

package.loaded.vfs = localvfs
