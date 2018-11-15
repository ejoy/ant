--luacheck: globals import
local require = import and import(...) or require

-- Editor or test use vfs.local to manage a VFS dir/repo.
-- It read/write file from/to a repo

local localvfs = {} ; localvfs.__index = localvfs

local fs = require "filesystem"
local access = require "repoaccess"

local function isdir(filepath)
	return fs.attributes(filepath, "mode") == "directory"
end

--luacheck: ignore readmount
local function readmount(filename)
	local f = io.open(filename, "rb")
	local ret = {}
	if not f then
		return ret
	end
	for line in f:lines() do
		local name, path = line:match "^(.-):(.*)"
		if name == nil then
			f:close()
			error ("Invalid .mount file : " .. line)
		end
		ret[name] = path
	end
	f:close()
	return ret
end

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
	}
end

function localvfs.mount(mountpoint, enginepath)	
	self = mount_repo(mountpoint, enginepath or ".")
end

function localvfs.open(repopath)
	assert(self == nil, "Can't open twice")
	if not isdir(repopath) then
		return
	end

	local mountpoint = access.readmount(repopath .. "/.mount")
	self = mount_repo(mountpoint, repopath)
	return true
end

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local fileconvert = require "fileconvert"
	rp = fileconvert(rp)
	return  rp, pathname:match "^/?(.-)/?$"
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
		item[filename] = not not isdir(realpath)
	end
	self._cache[path] = item
	return item
end

return localvfs

