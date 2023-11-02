local lfs = require "bee.filesystem"
local fastio = require "fastio"
local datalist = require "datalist"
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
	local filehash = self._filehash
	local list = vfsrepo:export()
	for i = 1, #list do
		local v = list[i]
		local n = filehash[v.hash]
		if not n then
			filehash[v.hash] = {
				path = v.path,
				dir = v.dir,
			}
		elseif n.dir then
			assert(v.dir == n.dir)
		elseif v.path ~= n.path then
			assert(fastio.readall_s(v.path) == fastio.readall_s(n.path))
		end
	end
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
	export_hash(self, vfsrepo, "wb")
end

function REPO_MT:root()
	return self._vfsrepo:root()
end

function REPO_MT:mountlapth()
	return self._mountlpath
end

function REPO_MT:file(pathname)
	local vfsrepo = self._vfsrepo
	return vfsrepo:file(pathname)
end

function REPO_MT:virtualpath(pathname)
	local vfsrepo = self._vfsrepo
	local _, vpath = vfsrepo:vpath(pathname)
	return vpath
end

function REPO_MT:hash(hash)
	return self._filehash[hash]
end

function REPO_MT:export_resources()
	local vfsrepo = self._vfsrepo
	return vfsrepo:resources()
end

local resource_filter <const> = {
	resource = { },
	whitelist = {
		"prefab",
		"bin",
		"cfg",
		"ozz",
		"vbbin",
		"vb2bin",
		"ibbin",
		"meshbin",
		"skinbin",
		"attr",
	},
}

local root_filter <const> = {
	resource = { "material" , "glb" , "texture" },
	whitelist = {
		"settings",
		"cfg",
		-- ecs
		"prefab",
		"ecs",
		-- script
		"lua",
		-- ui
		"rcss",
		"rml",
		-- effect
		"efk",
		-- font
		"ttf",
		"otf", --TODO: remove it?
		"ttc", --TODO: remove it?
		-- sound
		"bank",
		-- animation
		"event",
		"anim",
		-- material
		"state",
	},
}

function REPO_MT:build_resource(path, name)
	local vfsrepo = new_vfsrepo()
	vfsrepo:init {
		{ path = path, mount = "" },
-- name is vfs path, unused
--		name = name,
		hash = self._hashs,
		filter = resource_filter
	}
	export_hash(self, vfsrepo, "ab")
	return vfsrepo:root()
end

local function read_vfsignore(rootpath)
	if not lfs.exists(rootpath / ".vfsignore") then
		return {}
	end
	return datalist.parse(fastio.readall((rootpath / ".vfsignore"):string()))
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
		_filehash = {},
		_lock = filelock(cachepath),	-- lock repo
	}
	local vfsignore = read_vfsignore(rootpath)
	local config = {
		hash = import_hash(self),
		filter = {
			resource = root_filter.resource,
			whitelist = root_filter.whitelist,
			block = vfsignore.block,
			ignore = vfsignore.ignore,
		},
	}
	for i = 1, #repo._mountlpath do
		config[#config+1] = {
			mount = repo._mountvpath[i]:sub(1,-2),
			path = repo._mountlpath[i]:string(),
		}
	end
	vfsrepo:init(config)
	export_hash(self, vfsrepo, "wb")
	return setmetatable(self, REPO_MT)
end

