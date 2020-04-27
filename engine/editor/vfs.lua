local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
local repo = require "vfs.repo"

local self

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local ext = rp:extension():string():lower()
	if self._link[ext] then
		local compile_resource = import_package "ant.compile_resource".compile
		return compile_resource(rp)
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

function localvfs.identity(ext, identity)
	self._link[ext] = {identity=identity}
end

function localvfs.new(path)
	self = assert(repo.new(path))
	self._parentpath = path
end

function localvfs.reset(path)
	local old = self
	self = assert(repo.new(path, old._parentpath))
	self._parentpath = old._parentpath
	self._link = old._link --TODO:
	require "antpm".initialize()
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

function localvfs.unmount(name)
	if self._mountpoint[name] then
		local mnames = self._mountname
		for i, n in ipairs(mnames) do
			if n == name then
				table.remove(mnames,i)
				self._mountpoint[name] = nil
				return true
			end
		end
	end
end

function localvfs.repo()
	return self
end

package.loaded.vfs = localvfs
