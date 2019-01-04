-- Editor or test use vfs.local to manage a VFS dir/repo.
-- It read/write file from/to a repo

local localvfs = {} ; localvfs.__index = localvfs

local fs = require "filesystem"
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

function localvfs.mount(mountpoint, enginepath)
	self = mount_repo(mountpoint, enginepath or ".")
end

function localvfs.open(repopath)
	assert(self == nil, "Can't open twice")
	if not fs.is_directory(repopath) then
		return
	end

	local mountpoint = access.readmount(repopath / ".mount")
	self = mount_repo(mountpoint, repopath)
	return true
end

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local lk = rp:parent_path() / (rp:filename():string() .. ".lk")
	if fs.exists(lk) then
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
		item[filename] = not not fs.is_directory(realpath)
	end
	self._cache[path] = item
	return item
end

function localvfs.type(filepath)
	local rp = access.realpath(self, filepath)
	if fs.is_directory(rp) then
		return "dir"
	elseif fs.is_regular_file(rp) then
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

localvfs.localvfs = true

return localvfs
