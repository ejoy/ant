-- Editor or test use vfs.local to manage a VFS dir/repo.
-- It read/write file from/to a repo

local localvfs = {} ; localvfs.__index = localvfs

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

-- open a repo in repopath

local cachemeta = { __mode = "kv" }
local self

local function mount_repo(mountpoint, repopath)
	local rootpath = mountpoint[''] or repopath
	local mountname = access.mountname(mountpoint)

	return {
		_mountname = mountname,
		_mountpoint = mountpoint,
		_root = rootpath,
		_cache = setmetatable({} , cachemeta),
		_repo = rootpath / ".repo",
	}
end

function localvfs.add_mount(name, mountpath)
	assert(self, "need open repo before add")
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

function localvfs.remove_mount(name)
	assert(self)
	local mnames = self._mountname
	for idx, n in ipairs(mnames) do
		if n == name then
			table.remove(mnames, idx)
			self._mountpoint[name] = nil
			return true
		end
	end
end

function localvfs.mount(mountpoint, enginepath)
	self = mount_repo(mountpoint, enginepath or ".")
end

-- TODO, remove localvfs.open, will not depend on .mount file, only engine root path is needed
function localvfs.open(repopath)
	assert(self == nil, "Can't open twice")
	if not lfs.is_directory(repopath) then
		return
	end

	local mountpoint = access.readmount(repopath / ".mount")
	self = mount_repo(mountpoint, repopath)
	return true
end

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local lk = lfs.path(rp:string() .. ".lk")
	if lfs.exists(lk) then
		local binhash = access.build_from_path(self, self.identity, pathname)
		if binhash == nil then
			error(string.format("build from path failed, pathname:%s, log file can found in log folder", pathname))
		end
		return access.repopath(self, binhash):string()
	end
	return rp:string(), pathname:match "^/?(.-)/?$"
end

-- list files { name : type (dir/file) }
function localvfs.list(path)
	path = path:match "^/?(.-)/?$"
	local item = self._cache[path]
	if item then
		return item
	end
	local files = access.list_files(self, path)
	path = path .. '/'
	item = {}
	for filename in pairs(files) do
		local realpath = access.realpath(self, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	self._cache[path] = item
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

function localvfs.repopath()
	return self._repo
end

function localvfs.identity(identity)
	assert(self.identity == nil)
	self.identity = identity
end

local repopath = lfs.current_path()
localvfs.mount({["engine"] = repopath}, repopath)

local repo_cachepath = localvfs.repopath()
if not lfs.exists(repo_cachepath) then
	lfs.create_directories(repo_cachepath)
	for i=0,0xff do
		local abspath = repo_cachepath / string.format("%02x", i)
		lfs.create_directories(abspath)
	end
end

package.loaded.vfs = localvfs

