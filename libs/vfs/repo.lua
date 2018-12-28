--luacheck: globals import
local require = import and import(...) or require

-- This module can build/rebuild a directory into a repo.
--

local undef = nil
local _DEBUG = _G._DEBUG
local repo = {}
repo.__index = repo

local fs = require "lfs"
local access = require "repoaccess"

local function addslash(name)
	return (name:gsub("[/\\]?$","/"))
end

local function isdir(filepath)
	return fs.attributes(filepath, "mode") == "directory"
end

local function isfile(filepath)
	return fs.attributes(filepath, "mode") == "file"
end

local function filelock(filepath)
	return assert(fs.lock_dir(filepath), "repo is locking. (" .. filepath .. ")")
end

local function filetime(filepath)
	return fs.attributes(filepath, "modification")
end

local function refname(self, hash)
	return string.format("%s/%s/%s.ref", self._repo, hash:sub(1,2), hash)
end

function repo.new(rootpath)
	rootpath = addslash(rootpath)
	local repopath = rootpath .. ".repo"

	if not isdir(repopath) then
		return
	end

	local mountpoint = access.readmount(rootpath .. ".mount")
	rootpath = mountpoint[''] or rootpath
	local mountname = access.mountname(mountpoint)
	return setmetatable({
		_mountname = mountname,
		_mountpoint = mountpoint,
		_root = rootpath,
		_repo = repopath,
		_namecache = {},
		_lock = filelock(repopath),	-- lock repo
	}, repo)
end

local sha1_from_file = access.sha1_from_file
local sha1 = access.sha1

-- map path in repo to realpath (replace mountpoint)
function repo:realpath(filepath)
	return access.realpath(self, filepath)
end

-- build cache, cache is a table link list of sha1->{ filelist = ,  filename = , timestamp= , next= }
-- filepath should be end of / or '' for root
-- returns hash of dir
local function repo_build_dir(self, filepath, cache, namehashcache)
	local function add_item(hash, item)
		item.next = cache[hash]
		cache[hash] = item
	end
	local cache_hash = namehashcache[filepath]
	if cache_hash then
		if _DEBUG then print("CACHE", cache_hash.hash, filepath) end
		local hash = cache_hash.hash
		add_item(hash, { filelist = cache_hash.filelist	, filename = filepath })
		return hash
	end
	local rpath = self:realpath(filepath)
	local hashs = {}
	local files = access.list_files(self, filepath)

	for name in pairs(files) do
		local fullname = filepath == '' and name or filepath .. '/' .. name	-- full name in repo
		local realfullname = rpath .. '/' .. name	-- full name in local file system
		if self._mountpoint[fullname] or isdir(realfullname) then
			local hash = repo_build_dir(self, fullname, cache, namehashcache)
			table.insert(hashs, string.format("d %s %s", hash, name))
		else
			local mtime = filetime(realfullname)	-- timestamp
			local cache_hash = namehashcache[fullname]
			local hash
			if cache_hash and mtime == cache_hash.timestamp then
				-- file not change
				hash = cache_hash.hash
				if _DEBUG then print("CACHE", hash, fullname) end
			else
				hash = sha1_from_file(realfullname)
				namehashcache[fullname] = { hash = hash, timestamp = mtime }
				if _DEBUG then print("FILE", hash, fullname, mtime) end
			end
			add_item(hash, {
				filename = fullname,
				timestamp = mtime,
			})
			table.insert(hashs, string.format("f %s %s", hash, name))
		end
	end
	table.sort(hashs)
	local content = table.concat(hashs, "\n")
	local hash = sha1(content)
	add_item(hash, { filelist = content	, filename = filepath })
	namehashcache[filepath] = { hash = hash, filelist = content }	-- cache hash with filepath
	if _DEBUG then print("DIR", hash, filepath) end
	return hash
end

local function repo_write_cache(self, cache)
	for hash, content in pairs(cache) do
		local refset = {}
		local ref = {}
		local writedir = false
		repeat
			if content.timestamp then
				table.insert(ref, string.format("f %s %d", content.filename, content.timestamp))
			else
				-- it's dir
				if not writedir and content.filelist then
					local filepath = self._repo .. "/" .. hash:sub(1,2) .. "/" .. hash
					if not isfile(filepath) then
						local f = assert(io.open(filepath, "wb"))
						f:write(content.filelist)
						f:close()
					end
					writedir = true
				end
				table.insert(ref, string.format("d %s", content.filename))
			end
			refset[content.filename] = true
			content = content.next
		until content == nil
		if #ref > 0 then
			local filepath = refname(self, hash)
			local f = io.open(filepath, "rb")
			if f then
				-- merge ref file
				for line in f:lines() do
					local filename = line:match "^[df] (.-) ?%d*$"
					if not refset[filename] then
						table.insert(ref, line)
						refset[filename] = true
					end
				end
				f:close()
			end
			table.sort(ref)

			f = assert(io.open(filepath, "wb"))
			f:write(table.concat(ref, "\n"))
			f:close()
		end
	end
end

local function repo_write_root(self, roothash)
	local root = assert(io.open(self._repo .. "/root", "wb"))
	root:write(roothash)
	root:close()
	if _DEBUG then print("ROOT", roothash) end
end

function repo:rebuild()
	self._namecache = {}	-- clear cache
	return self:build()
end

function repo:build()
	local cache = {}
	self._namecache[''] = undef
	local roothash = repo_build_dir(self, "", cache, self._namecache)

	repo_write_cache(self, cache)
	repo_write_root(self, roothash)

	self.dirty = nil

	return roothash
end

function repo:rebuild()
	self._namecache = {}	-- clear cache
	self:build()
end

function repo:close()
	self._lock:free()
	self._lock = nil
	self._mountname = nil
	self._mountpoint = nil
	self._root = nil
	self._repo = nil
	self._namecache = nil
end

--[[
	all path should be absolute path

	{ rootpath,
		xxx = mountxxx,
	}
]]
function repo.init(mount)
	local rootpath = mount[1]
	assert(isdir(rootpath), "Not a dir")
	rootpath = addslash(rootpath)
	local mountpath = rootpath .. ".mount"
	if isfile(mountpath) then
		for name, path in pairs(access.readmount(mountpath)) do
			print("Mount", name, path)
		end
	else
		local mountfile = {}
		for name, path in pairs(mount) do
			print("Mount", name, path)
			if name ~= 1 then
				table.insert(mountfile, string.format("%s %s", name, path))
			end
		end
		if #mountfile > 0 then
			table.sort(mountfile)
			local f = assert(io.open(mountpath, "wb"))
			f:write(table.concat(mountfile,"\n"))
			f:close()
		end
	end
	local repopath = rootpath .. ".repo"
	if not isdir(repopath) then
		-- already has .repo
		assert(fs.mkdir(repopath))
	end

	-- mkdir dirs
	for i=0,0xff do
		local path = string.format("%s/%02x", repopath , i)
		if not isdir(path) then
			assert(fs.mkdir(path))
		end
	end

	local rootf = repopath .. "/root"
	if not isfile(rootf) then
		-- rebuild repo
		local r = repo.new(rootpath)
		r:rebuild()
		-- unlock repo
		r:close()
	end
end

-- make file dirty, would build later
function repo:touch(pathname)
	self.dirty = true
	repeat
		local path = pathname:match "(.*)/"
		if _DEBUG then print("TOUCH", pathname) end
		self._namecache[pathname] = undef
		pathname = path
	until path == nil
end

function repo:touch_path(pathname)
	self.dirty = true
	if pathname == '' or pathname == '/' then
		-- clear all
		self._namecache = {}
		return
	end

	local namecache = self._namecache
	self:touch(pathname)
	pathname = addslash(pathname)
	local n = #pathname
	for name in pairs(namecache) do
		if name:sub(1,n) == pathname then
			if _DEBUG then print("TOUCH", name) end
			namecache[name] = undef
		end
	end
end

local function update_ref(filename, content)
	if #content == 0 then
		if _DEBUG then print("REMOVE", filename) end
		os.remove(filename)
	else
		if _DEBUG then print("UPDATE", filename) end
		local f = io.open(filename, "wb")
		f:write(table.concat(content, "\n"))
		f:close()
	end
end

local function read_ref(self, hash)
	local cache = self._namecache
	local filename = refname(self, hash)
	local items = {}
	local needupdate
	for line in io.lines(filename) do
		local name, ts = line:match "^[df] (.-) ?(%d*)$"
		if name == nil then
			if _DEBUG then print("INVALID", hash) end
			needupdate = true
		elseif cache[name] then
			needupdate = true
		else
			local timestamp = tonumber(ts)
			if timestamp then
				-- It's a file
				local realname = self:realpath(name)
				if isfile(realname) and filetime(realname) == timestamp then
					cache[name] = { hash = hash , timestamp = timestamp }
					table.insert(items, line)
				else
					needupdate = true
				end
			else
				-- remove dir
				needupdate = true
			end
		end
	end
	if needupdate then
		update_ref(filename, items)
	end
end

function repo:index()
	local repo = self._repo
	local namecache = {}
	self._namecache = namecache
	for i = 0, 0xff do
		local refpath = string.format("%s/%02x", repo, i)
		for name in fs.dir(refpath) do
			if name:sub(-4) == ".ref" then
				read_ref(self, name:sub(1,-5))
			end
		end
	end
	return self:build()
end

function repo:root()
	local f = io.open(self._repo .. "/root", "rb")
	if not f then
		return self:index()
	end
	local hash = f:read "a"
	f:close()
	return hash
end

-- return hash file's real path or nil (invalid hash, need rebuild)
function repo:hash(hash)
	local filename = string.format("%s/%s/%s", self._repo, hash:sub(1,2), hash)
	local f = io.open(filename, "rb")
	if f then
		f:close()
		-- it's a dir object
		return filename
	end
	local rfilename = filename .. ".ref"

	f = io.open(rfilename, "rb")
	if not f then
		return
	end
	for line in f:lines() do
		local name, timestamp = line:match "f (.-) ?(%d*)$"
		if timestamp then
			timestamp = tonumber(timestamp)
			local realpath = self:realpath(name)
			if filetime(realpath) == timestamp then
				f:close()
				return realpath
			end
		end
	end
	f:close()
end

function repo:dir(hash)
	local filename = string.format("%s/%s/%s", self._repo, hash:sub(1,2), hash)
	local f = io.open(filename, "rb")
	if not f then
		return
	end
	local dir = {}
	local file = {}
	for line in f:lines() do
		local t, hash, name = line:match "^([df]) (%S*) (.*)"
		if t == 'd' then
			dir[name] = hash
		elseif t == 'f' then
			file[name] = hash
		else
			if _DEBUG then print ("INVALID", filename) end
			f:close()
			return
		end
	end
	f:close()
	return { dir = dir, file = file }
end

function repo:link(hash, identity, source_hash, lk_hash)
	local source_path = self:hash(source_hash)
	local lk_path = self:hash(lk_hash)
	if not source_path or not lk_path then
		if _DEBUG then print ("LINKFAIL", identity, source_hash) end
		return
	end
	local binhash = access.build_from_file(self, hash, identity, source_path, lk_path)
	if not binhash then
		if _DEBUG then print ("BUILDFAIL", identity, source_hash, source_path) end
		return
	end
	return binhash
end

return repo
