local lfs = require "bee.filesystem"
local fastio = require "fastio"
local access = dofile "/engine/editor/vfs_access.lua"
local new_vfsrepo = require "vfsrepo".new

local REPO_MT = {}
REPO_MT.__index = REPO_MT

local function filelock(filepath)
	filepath = filepath / "vfs.lock"
	local f = lfs.filelock(filepath)
	return f or error ("repo is locking. (" .. filepath:string() .. ")")
end

local function import_hash(self)
	local hashspath = self._cachepath / "hashs"
	if not lfs.exists(hashspath) then
		return
	end
	local hashs = {}
	for line in fastio.readall_s(hashspath:string()):gmatch "(.-)\n+" do
		local sha1, timestamp, path = line:match "(%S+) (%S+) (.+)"
		hashs[path] = {sha1, tonumber(timestamp, 16)}
	end
	return hashs
end

local function export_hash(self, vfsrepo, mode)
	local hashspath = self._cachepath / "hashs"
	local hashs = vfsrepo:export_hash()
	local f <close> = assert(io.open(hashspath:string(), mode))
	for path, v in pairs(hashs) do
		f:write(string.format("%s %09x %s\n", v[1], v[2], path))
	end
	self._hashs = hashs
end

function REPO_MT:rebuild(changed)
	local vfsrepo = self._vfsrepo
	vfsrepo:update(changed)
	vfsrepo:hash_dirs(self._dirhash)
	vfsrepo:hash_files(self._filehash)
	export_hash(self, vfsrepo, "wb")
end

function REPO_MT:root()
	return self._vfsrepo:root()
end

function REPO_MT:mountlapth()
	return self._mountlpath
end

function REPO_MT:realpath(pathname)
	local vfsrepo = self._vfsrepo
	local file = vfsrepo:file(pathname)
	if file then
		return file.path
	end
end

function REPO_MT:virtualpath(pathname)
	local vfsrepo = self._vfsrepo
	local _, vpath = vfsrepo:vpath(pathname)
	return vpath
end

function REPO_MT:hash(hash)
	local dir = self._dirhash[hash]
	if dir then
		return "dir", dir
	end
	local file = self._filehash[hash]
	if file then
		return "file", file
	end
end

function REPO_MT:build_resource(path, name)
	local vfsrepo = new_vfsrepo()
	vfsrepo:init {
-- name is vfs path, unused
--		name = name,
		hash = self._hashs,
		{ path = path, mount = "" },
	}
	vfsrepo:hash_dirs(self._dirhash)
	vfsrepo:hash_files(self._filehash)
	export_hash(self, vfsrepo, "ab")
	return vfsrepo:root()
end

return function (rootpath)
	local cachepath = rootpath / ".fileserver"
	if not lfs.is_directory(rootpath) then
		return nil, "Not a dir"
	end
	if not lfs.is_directory(cachepath) then
		-- already has .repo
		assert(lfs.create_directories(cachepath))
	end
	local repo = { _root = rootpath }
	access.readmount(repo)
	local vfsrepo = new_vfsrepo()
	local self = {
		_vfsrepo = vfsrepo,
		_cachepath = cachepath,
		_mountlpath = repo._mountlpath,
		_dirhash = {},
		_filehash = {},
		_lock = filelock(cachepath),	-- lock repo
	}
	local config = {
		hash = import_hash(self),
	}
	for i = 1, #repo._mountlpath do
		config[#config+1] = {
			mount = repo._mountvpath[i]:sub(1,-2),
			path = repo._mountlpath[i]:string(),
		}
	end
	vfsrepo:init(config)
	vfsrepo:hash_dirs(self._dirhash)
	vfsrepo:hash_files(self._filehash)
	export_hash(self, vfsrepo, "wb")
	return setmetatable(self, REPO_MT)
end

