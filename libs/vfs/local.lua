local require = import and import(...) or require

-- Editor or test use vfs.local to manage a VFS dir/repo.
-- It read/write file from/to a repo

local localvfs = {} ; localvfs.__index = localvfs

local fs = require "filesystem"
local access = require "repoaccess"

-- todo:
local function engine_path()
	return os.getenv "ANTGE" or fs.currentdir()
end

local function isdir(filepath)
	return fs.attributes(filepath, "mode") == "directory"
end

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

function localvfs.open(repopath)
	if not isdir(repopath) then
		return
	end

	local mountpoint = access.readmount(repopath .. "/.mount")
	local rootpath = mountpoint[''] or repopath
	local mountname = access.mountname(mountpoint)

	return setmetatable({
		_mountname = mountname,
		_mountpoint = mountpoint,
		_root = rootpath,
		_cache = setmetatable({} , cachemeta),
	}, localvfs)
end

localvfs.realpath = access.realpath

-- list files { name : type (dir/file) }
function localvfs:list(path)
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
		if isdir(realpath) then
			item[filename] = 'dir'
		else
			item[filename] = 'file'
		end
	end
	self._cache[path] = item
	return item
end

function localvfs:uid(filepath)
	return filepath:match "^/?(.-)/?$"
end

return localvfs

