local lfs = require "bee.filesystem"
local sys = require "bee.sys"
local fastio = require "fastio"
local datalist = require "datalist"
local mount = require "mount"
local new_vfsrepo = require "vfsrepo".new

local REPO_MT = {}
REPO_MT.__index = REPO_MT

function REPO_MT:__close()
	self._lock:close()
end

function REPO_MT:close()
	self._lock:close()
end

local function filelock(filepath)
	filepath = filepath / "vfs.lock"
	local f = sys.filelock(filepath)
	return f or error ("repo is locking. (" .. filepath:string() .. ")")
end

local function import_hash(self)
	if self._nohash then
		return false
	end
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

local function read_content(v)
	if v.dir then
		return v.dir
	end
	if v.path then
		return fastio.readall_s(v.path)
	end
	assert(false)
end

local function export_filehash(self, vfsrepo)
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
		else
			--assert(read_content(v) == read_content(n))
		end
	end
end

local function export_hash(self, vfsrepo, mode)
	local hashspath = self._cachepath / "hashs"
	local hashs = vfsrepo:export_hash()
	local f <close> = assert(io.open(hashspath:string(), mode))
	for path, v in pairs(hashs) do
		f:write(string.format("%s %09x %s\n", v[1], v[2], path))
		self._hashs[path] = v
	end
end

function REPO_MT:rebuild(changed)
	local vfsrepo = self._vfsrepo
	vfsrepo:update(changed)
	export_filehash(self, vfsrepo)
	export_hash(self, vfsrepo, "wb")
end

function REPO_MT:root()
	local vfsrepo = self._vfsrepo
	return vfsrepo:root()
end

function REPO_MT:initconfig()
	return self._config
end

function REPO_MT:file(pathname)
	local vfsrepo = self._vfsrepo
	return vfsrepo:file(pathname)
end

function REPO_MT:valid_path(pathname)
	local vfsrepo = self._vfsrepo
	return vfsrepo:valid_path(pathname)
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
		"ant",
		"ozz",
		"vbbin",
		"vb2bin",
		"ibbin",
		"meshbin",
		"skinbin",
	},
}

local resource <const> = { "material" , "glb" , "gltf", "texture" }

local block <const> = {
    "/res",
    "/pkg/ant.bake",
}

local whitelist <const> = {
	"ant",
	-- ecs
	"prefab",
	"ecs",
	-- script
	"lua",
	-- ui
	"html",
	"css",
	-- effect
	"efk",
	-- font
	"ttf",
	"otf", --TODO: remove it?
	"ttc", --TODO: remove it?
	-- sound
	"bank",
	-- material
	"state",    --TODO: use ant
	"varyings", --TODO: use ant
	"atlas"
}

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

function REPO_MT:build_resource(path)
	local vfsrepo = new_vfsrepo()
	local config = {{
		path = path,
		mount = "/",
		filter = resource_filter
	}}
	if self._nohash then
		config.hash = false
		vfsrepo:init(config)
	else
		config.hash = self._hashs
		vfsrepo:init(config)
		export_filehash(self, vfsrepo)
	end
	export_hash(self, vfsrepo, "ab")
	return vfsrepo
end

local function read_vfsignore(rootpath)
	if not lfs.exists(rootpath / ".vfsignore") then
		return {
			whitelist = whitelist,
			block = block,
		}
	end
	local r = datalist.parse(fastio.readall_f((rootpath / ".vfsignore"):string()))
	if r.whitelist then
		table_append(r.whitelist, whitelist)
	else
		r.whitelist = whitelist
	end
	if r.block then
		table_append(r.block, block)
	else
		r.block = block
	end
	return r
end

local function new_std(t)
	local rootpath = lfs.path(t.rootpath)
	local cachepath = rootpath / ".app"
	if not lfs.is_directory(rootpath) then
		return nil, "Not a dir"
	end
	if not lfs.is_directory(cachepath) then
		assert(lfs.create_directories(cachepath))
	end
	local repo = { _root = rootpath }
	mount.read(repo)
	local vfsrepo = new_vfsrepo()
	local self = {
		_nohash = t.nohash,
		_vfsrepo = vfsrepo,
		_cachepath = cachepath,
		_filehash = {},
		_hashs = {},
		_lock = filelock(cachepath),	-- lock repo
	}
	local vfsignore = read_vfsignore(rootpath)
	local config = {
		hash = import_hash(self),
	}
	for i = 1, #repo._mountlpath do
		config[#config+1] = {
			mount = repo._mountvpath[i]:sub(1,-2),
			path = repo._mountlpath[i]:string(),
			filter = {
				resource = resource,
				whitelist = vfsignore.whitelist,
				block = vfsignore.block,
				ignore = vfsignore.ignore,
			},
		}
	end
	if not t.nohash then
		if t.resource_settings then
			for _, setting in ipairs(t.resource_settings) do
				local path = repo._root / "res" / setting
				if lfs.is_directory(path) then
					config[#config+1] = {
						mount = "/res/" .. setting,
						path = path:string(),
						filter = resource_filter,
					}
				end
			end
		else
			local path = repo._root / "res"
			if lfs.is_directory(path) then
				config[#config+1] = {
					mount = "/res",
					path = path:string(),
					filter = resource_filter,
				}
			end
		end
	end
	self._config = config
	vfsrepo:init(config)
	if not t.nohash then
		export_filehash(self, vfsrepo)
		export_hash(self, vfsrepo, "wb")
	end
	return setmetatable(self, REPO_MT)
end

return new_std
