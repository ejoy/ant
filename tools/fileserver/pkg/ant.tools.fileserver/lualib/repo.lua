-- This module can build/rebuild a directory into a repo.
--

local undef = nil
local _DEBUG = _G._DEBUG
local REPO_MT = {}
REPO_MT.__index = REPO_MT

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
local crypt = require "crypt"

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

local function sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

local sha1_encoder = crypt.sha1_encoder()

local function sha1_from_file(filename)
	sha1_encoder:init()
	local ff = assert(lfs.open(filename, "rb"))
	while true do
		local content = ff:read(1024)
		if content then
			sha1_encoder:update(content)
		else
			break
		end
	end
	ff:close()
	return sha1_encoder:final():gsub(".", byte2hex)
end

local repo_build_dir

local function is_resource(path)
	local ext = path:match "[^/]%.([%w*?_%-]*)$"
	if ext ~= "material" and ext ~= "glb"  and ext ~= "texture" and ext ~= "png" then
		return false
	end
	return true
end

local function addslash(name)
	return (name:gsub("[/\\]?$","/"))
end

local function filelock(filepath)
	filepath = filepath / "vfs.lock"
	local f = lfs.filelock(filepath)
	return assert(f, "repo is locking. (" .. filepath:string() .. ")")
end

local function refname(self, hash)
	return self._repo / hash:sub(1,2) / (hash .. ".ref")
end

function REPO_MT.new(rootpath)
	local repopath = rootpath / ".repo"
	if not lfs.is_directory(rootpath) then
		return nil, "Not a dir"
	end
	if not lfs.is_directory(repopath) then
		-- already has .repo
		assert(lfs.create_directories(repopath))
	end
	for i = 0, 0xff do
		local path = repopath / string.format("%02x", i)
		if not lfs.is_directory(path) then
			assert(lfs.create_directories(path))
		end
	end
	local r = {
		_root = rootpath,
		_repo = repopath,
		_namecache = {},
		_lock = filelock(repopath),	-- lock repo
	}
	access.readmount(r)
	return setmetatable(r, REPO_MT)
end

-- map path in repo to realpath (replace mountpoint)
function REPO_MT:realpath(filepath)
	local rp = access.realpath(self, filepath)
	assert(rp ~= nil)
	return rp
end

function REPO_MT:virtualpath(pathname)
	return access.virtualpath(self, pathname)
end

-- build cache, cache is a table link list of sha1->{ filelist = ,  filename = , timestamp= , next= }
-- filepath should be end of / or '' for root
-- returns hash of dir
function repo_build_dir(self, filepath, cache, namehashcache)
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
	local hashs = {}
	local filelist = access.list_files(self, filepath)
	for _, name in ipairs(filelist) do
		local fullname = filepath .. name	-- full name in repo
		if not self._resource and is_resource(fullname) then
			table.insert(hashs, string.format("r %s %s", name, fullname))
		else
			if filelist[name] == "v" or lfs.is_directory(self:realpath(fullname)) then
				local hash = repo_build_dir(self, fullname .. '/', cache, namehashcache)
				table.insert(hashs, string.format("d %s %s", name, hash))
			else
				local realfullname = self:realpath(fullname)
				local mtime = lfs.last_write_time(realfullname)	-- timestamp
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
					filename = realfullname,
					timestamp = mtime,
				})
				table.insert(hashs, string.format("f %s %s", name, hash))
			end
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
					local filepath = self._repo / hash:sub(1,2) / hash
					if not lfs.is_regular_file(filepath) then
						local f = assert(lfs.open(filepath, "wb"))
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
			local f = lfs.open(filepath, "rb")
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

			f = assert(lfs.open(filepath, "wb"))
			f:write(table.concat(ref, "\n"))
			f:close()
		end
	end
end

local function repo_write_root(self, roothash)
	local root = assert(lfs.open(self._repo / "root", "wb"))
	root:write(roothash)
	root:close()
	if _DEBUG then print("ROOT", roothash) end
end

function REPO_MT:rebuild()
	self._namecache = {}	-- clear cache
	return self:build()
end

function REPO_MT:build()
	access.readmount(self)

	local cache = {}
	self._namecache[''] = undef
	local roothash = repo_build_dir(self, "/", cache, self._namecache)

	repo_write_cache(self, cache)
	repo_write_root(self, roothash)

	self.dirty = nil

	return roothash
end

function REPO_MT:close()
	self._lock:close()
	self._lock = nil
	--self._mountpoint = nil
	--self._root = nil
	--self._repo = nil
	--self._namecache = nil
end

-- make file dirty, would build later
function REPO_MT:touch(pathname)
	self.dirty = true
	repeat
		local path = pathname:match "(.*)/"
		if _DEBUG then print("TOUCH", pathname) end
		self._namecache[pathname] = undef
		pathname = path
	until path == nil
end

function REPO_MT:touch_path(pathname)
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
		lfs.remove(filename)
	else
		if _DEBUG then print("UPDATE", filename) end
		local f = lfs.open(filename, "wb")
		f:write(table.concat(content, "\n"))
		f:close()
	end
end

local function read_ref(self, hash)
	local cache = self._namecache
	local filename = refname(self, hash)
	local items = {}
	local needupdate
	for line in io.lines(filename:string()) do
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
				-- TODO
				if lfs.is_regular_file(name) and lfs.last_write_time(name) == timestamp then
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

function REPO_MT:index()
	local repopath = self._repo
	local namecache = {}
	self._namecache = namecache
	for i = 0, 0xff do
		local refpath = repopath / string.format("%02x", i)
		for name in lfs.pairs(refpath) do
			if name:extension():string() == ".ref" then
				read_ref(self, name:stem():string())
			end
		end
	end
	return self:build()
end

function REPO_MT:root()
	local f = lfs.open(self._repo / "root", "rb")
	if not f then
		return self:index()
	end
	local hash = f:read "a"
	f:close()
	return hash
end

-- return hash file's real path or nil (invalid hash, need rebuild)
function REPO_MT:hash(hash)
	local filename = self._repo / hash:sub(1,2) / hash
	local f = lfs.open(filename, "rb")
	if f then
		f:close()
		-- it's a dir object
		return filename:string()
	end
	local rfilename = filename:replace_extension(".ref")

	f = lfs.open(rfilename, "rb")
	if not f then
		return
	end
	for line in f:lines() do
		local name = line:match "f (.-) ?(%d*)$"
		if name then
			f:close()
			return name
		end
	end
	f:close()
end

function REPO_MT:dir(hash)
	local filename = self._repo / hash:sub(1,2) / hash
	local f = lfs.open(filename, "rb")
	if not f then
		return
	end
	local dir = {}
	local file = {}
	local resource = {}
	for line in f:lines() do
		local t, name, hash = line:match "^([dfr]) (%S*) (%S*)$"
		if t == 'd' then
			dir[name] = hash
		elseif t == 'f' then
			file[name] = hash
		elseif t == 'r' then
			resource[name] = hash
		else
			if _DEBUG then print ("INVALID", filename) end
			f:close()
			return
		end
	end
	f:close()
	return { dir = dir, file = file, resource = resource }
end

function REPO_MT:build_dir(lpath)
	lpath = lfs.path(lpath)
	local r = {
		_root = self._root,
		_repo = self._repo,
		_namecache = {},
		_mountpoint = {},
		_resource = true,
	}
	access.addmount(r, lpath)
	setmetatable(r, REPO_MT)
	local cache = {}
	local roothash = repo_build_dir(r, "/", cache, r._namecache)
	repo_write_cache(r, cache)
	return roothash
end

local function split(path)
	local r = {}
	path:gsub("[^/]+", function(s)
		r[#r+1] = s
	end)
	return r
end

local function fetchall(self, r, hash)
	local v = self:dir(hash)
	for _, h in pairs(v.file) do
		r[#r+1] = h
	end
	for _, h in pairs(v.dir) do
		r[#r+1] = h
		fetchall(self, r, h)
	end
end

function REPO_MT:fetch(path)
	local r = {}
	local hash = self:root()
	for _, name in ipairs(split(path)) do
		local v = self:dir(hash)
		r[#r+1] = hash
		hash = v.dir[name]
		if not hash then
			return
		end
	end
	r[#r+1] = hash
	fetchall(self, r, hash)
	return r
end

local function fetch_path(repo, hash, path, hashs, resource_hashs, unsolved_hashs, error_hashs)
	local pathlst = split(path)
	local n = #pathlst
	for i = 1, n-1 do
		local name = pathlst[i]
		local v = repo:dir(hash)
		if not v or not v.dir[name] then
			error_hashs[#error_hashs+1] = hash
			return
		end
		hashs[#hashs+1] = hash
		hash = v.dir[name]
	end
	local name = pathlst[n]
	local v = repo:dir(hash)
	if not v then
		error_hashs[#error_hashs+1] = hash
		return
	end
	if v.resource[name] then
		resource_hashs[#resource_hashs+1] = hash
		return
	end
	if v.file[name] then
		hashs[#hashs+1] = hash
		return
	end
	if v.dir[name] then
		unsolved_hashs[#unsolved_hashs+1] = hash
		return
	end
	error_hashs[#error_hashs+1] = hash
end

function REPO_MT:fetch_path(hash, path)
	local hashs = {}
	local unsolved_hashs = {}
	local resource_hashs = {}
	local error_hashs = {}
	fetch_path(self, hash, path, hashs, unsolved_hashs, resource_hashs, error_hashs)
	return table.concat(hashs, "|")
		, table.concat(resource_hashs, "|")
		, table.concat(unsolved_hashs, "|")
		, table.concat(error_hashs, "|")
end

local function fetch_dir(repo, hash, n, hashs, resource_hashs, unsolved_hashs, error_hashs)
	local v = repo:dir(hash)
	if not v then
		error_hashs[#error_hashs+1] = hash
		return
	end
	for _, h in pairs(v.file) do
		hashs[#hashs+1] = h
	end
	for _, h in pairs(v.resource) do
		resource_hashs[#resource_hashs+1] = h
	end
	for _, h in pairs(v.dir) do
		if n <= 0 then
			unsolved_hashs[#unsolved_hashs+1] = hash
		else
			hashs[#hashs+1] = h
			fetch_dir(repo, h, n-1, hashs, resource_hashs, unsolved_hashs, error_hashs)
		end
	end
end

function REPO_MT:fetch_dir(hash)
	local hashs = {}
	local resource_hashs = {}
	local unsolved_hashs = {}
	local error_hashs = {}
	fetch_dir(self, hash, 2, hashs, resource_hashs, unsolved_hashs, error_hashs)
	return table.concat(hashs, "|")
		, table.concat(resource_hashs, "|")
		, table.concat(unsolved_hashs, "|")
		, table.concat(error_hashs, "|")
end

return REPO_MT
