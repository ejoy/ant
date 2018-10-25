local require = import and import(...) or require
--local log = log and log(...) or print

-- Editor or test use vfs.local to manage a VFS dir/repo.
-- It read/write file from/to a repo

local localvfs = {}

local repo = require "repo"
local fs = require "filesystem"

local _repo
local _repo_root
local cache_fetch = { __mode = "kv" }
local cache = setmetatable({} , cache_fetch )

function cache_fetch:__index(pathname)
	if pathname == '' then
		local rootobj = _repo:hash(_repo_root)
		self[''] = rootobj
		return rootobj
	end
	local path, name = pathname:match "(.*)/(.-)$"
	if path == nil then
		path = ''
		name = pathname
	end
	local dir = self[path]
	local obj = dir.dir[name]
	self[pathname] = obj
	return obj
end

local function repo_path(name)
	return fs.personaldir() .. "/" .. name
end

-- todo:
local function engine_path()
	return os.getenv "ANTGE" or fs.currentdir()
end

-- init a repo in my documents
function localvfs.init( name , mount)
	local path = repo_path(name)
	local ant = engine_path()
	local config = {
		path,
		["engine/libs"] = ant .. "/libs",
		["engine/assets"] = ant .. "/assets",
	}
	if mount then
		for k, v in pairs(mount) do
			config[k] = v
		end
	end
	repo.init(config)
	local enginepath = path .. "/engine"
	fs.mkdir(enginepath)
end

-- open a repo
function localvfs.open( name )
	assert(_repo == nil, "Already open a repo")
	_repo = repo.new(repo_path(name))
	return _repo ~= nil
end

local function find_name(dir, name)
	local f = dir.file[name]
	if f then
		return f, "file"
	else
		local d = dir.dir[name]
		if d then
			return d, "dir"
		end
	end
end

-- returns a hash (different pathname may share the same hash) in a repo for reading
function localvfs.hash( pathname )
	local path, name = pathname:match "(.*)/(.-)$"
	if path == nil then
		if pathname == '' then
			return _repo_root
		end
		path = ''
		name = pathname
	end
	return find_name(cache[path], name)
end

-- returns a filename with hash in a repo
function localvfs.filename( hash )
	return _repo:hash(hash)
end

-- returns a filename in a repo for writing
function localvfs.writefile( pathname )
	return _repo:realpath(pathname)
end

function localvfs.mkdir( pathname )
	local path, name = pathname:match "(.*)/(.-)$"
	local realpath = _repo:realpath(path)
	return fs.mkdir(realpath .. "/" .. name)
end

-- return { dir = { hashes } , file = { hashes } }
function localvfs.list( hash )
	return _repo:dir(hash)
end

function localvfs.build(rebuild)
	local oldroot = _repo_root
	if rebuild then
		_repo_root = _repo:rebuild()
	else
		_repo_root = _repo:build()
	end
	if oldroot ~= _repo_root then
		cache = setmetatable({} , cache_fetch )
	end
end

function localvfs.touch(pathname)
	_repo:touch(pathname)
end

return localvfs

