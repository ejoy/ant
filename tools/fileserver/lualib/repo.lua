-- This module can build/rebuild a directory into a repo.
--

local undef = nil
local _DEBUG = _G._DEBUG
local repo = {}
repo.__index = repo

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
	if ext ~= "sc" and ext ~= "glb"  and ext ~= "texture" and ext ~= "png" then
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

function repo.new(rootpath)
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
	return setmetatable(r, repo)
end

-- map path in repo to realpath (replace mountpoint)
function repo:realpath(filepath)
	return access.realpath(self, filepath)
end

function repo:virtualpath(pathname)
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
	for name, type in pairs(access.list_files(self, filepath)) do
		local fullname = filepath == '' and name or filepath .. '/' .. name	-- full name in repo
		if not is_resource(fullname) then
			if type == "v" or lfs.is_directory(access.realpath(self, fullname)) then
				local hash = repo_build_dir(self, fullname, cache, namehashcache)
				table.insert(hashs, string.format("d %s %s", hash, name))
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
					filename = fullname,
					timestamp = mtime,
				})
				table.insert(hashs, string.format("f %s %s", hash, name))
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

function repo:rebuild()
	self._namecache = {}	-- clear cache
	return self:build()
end

function repo:build()
	access.readmount(self)

	local cache = {}
	self._namecache[''] = undef
	local roothash = repo_build_dir(self, "", cache, self._namecache)

	repo_write_cache(self, cache)
	repo_write_root(self, roothash)

	self.dirty = nil

	return roothash
end

function repo:close()
	self._lock:close()
	self._lock = nil
	--self._mountname = nil
	--self._mountpoint = nil
	--self._root = nil
	--self._repo = nil
	--self._namecache = nil
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
	for line in lfs.lines(filename) do
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
				if not realname:string():match "%?" and lfs.is_regular_file(realname) and lfs.last_write_time(realname) == timestamp then
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
	local repopath = self._repo
	local namecache = {}
	self._namecache = namecache
	for i = 0, 0xff do
		local refpath = repopath / string.format("%02x", i)
		for name in refpath:list_directory() do
			if name:extension():string() == ".ref" then
				read_ref(self, name:stem():string())
			end
		end
	end
	return self:build()
end

function repo:root()
	local f = lfs.open(self._repo / "root", "rb")
	if not f then
		return self:index()
	end
	local hash = f:read "a"
	f:close()
	return hash
end

-- return hash file's real path or nil (invalid hash, need rebuild)
function repo:hash(hash)
	local filename = self._repo / hash:sub(1,2) / hash
	local f = lfs.open(filename, "rb")
	if f then
		f:close()
		-- it's a dir object
		return filename
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
			return self:realpath(name)
		end
	end
	f:close()
end

function repo:dir(hash)
	local filename = self._repo / hash:sub(1,2) / hash
	local f = lfs.open(filename, "rb")
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

function repo:build_dir(rpath, lpath)
	lpath = lfs.path(lpath)
	local r = {
		_root = self._root,
		_repo = self._repo,
		_namecache = {},
		_mountname = {},
		_mountpoint = {},
	}
	access.addmount(r, rpath, lpath)
	setmetatable(r, repo)
	local cache = {}
	local roothash = repo_build_dir(r, rpath, cache, r._namecache)
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

function repo:fetch(path)
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

return repo
