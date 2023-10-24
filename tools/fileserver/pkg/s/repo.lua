local lfs = require "bee.filesystem"
local fastio = require "fastio"
local access = dofile "/engine/vfs/repoaccess.lua"
local new_vfsrepo = require "vfsrepo".new

local REPO_MT = {}
REPO_MT.__index = REPO_MT

local function filelock(filepath)
	filepath = filepath / "vfs.lock"
	local f = lfs.filelock(filepath)
	return assert(f, "repo is locking. (" .. filepath:string() .. ")")
end

local function import_hash(self)
	local hashspath = self._cachepath / "hashs"
	if not lfs.exists(hashspath) then
		return
	end
	return fastio.readall_s(hashspath:string())
end

local function export_hash(self, vfsrepo, mode)
	local hashspath = self._cachepath / "hashs"
	local hashs = vfsrepo:export_hash()
	local f <close> = assert(io.open(hashspath:string(), mode))
	f:write(hashs)
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

function REPO_MT:build_resource(path)
	local vfsrepo = new_vfsrepo()
	vfsrepo:init {
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

