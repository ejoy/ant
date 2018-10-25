-- This module can build/rebuild a directory into a repo.
--

local undef = nil
local _DEBUG = _G._DEBUG
local repo = {}
repo.__index = repo

local fs = require "filesystem"
local crypt = require "crypt"

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
	return assert(fs.lock_dir(filepath), "repo is locking")
end

local function filetime(filepath)
	return fs.attributes(filepath, "modification")
end

local function refname(self, hash)
	return string.format("%s/%s/%s.ref", self._repo, hash:sub(1,2), hash)
end

local function readmount(filename)
	local f = io.open(filename, "rb")
	local ret = {}
	if not f then
		return ret
	end
	for line in f:lines() do
		local name, path = line:match "^%s*(.-)%s*:%s*(.-)%s*$"
		if name == nil then
			if not (line:match "^%s*#" or line:match "^%s*$") then
				f:close()
				error ("Invalid .mount file : " .. line)
			end
		end
		path = path:gsub("%s*#.*$","")	-- strip comment
		ret[name] = path
	end
	return ret
end

function repo.new(rootpath)
	rootpath = addslash(rootpath)
	local repopath = rootpath .. ".repo"

	if not isdir(repopath) then
		return
	end

	local mountpoint = readmount(rootpath .. ".mount")
	rootpath = mountpoint[''] or rootpath
	local mountname = {}

	for name, path in pairs(mountpoint) do
		if name ~= '' then
			table.insert(mountname, name)
		end
		mountpoint[name] = path
	end
	table.sort(mountname, function(a,b) return a>b end)
	return setmetatable({
		_mountname = mountname,
		_mountpoint = mountpoint,
		_root = rootpath,
		_repo = repopath,
		_namecache = {},	-- todo: read index cache
		_lock = filelock(repopath),	-- lock repo
	}, repo)
end

-- sha1
local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

local function sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

local sha1_encoder = crypt.sha1_encoder()

local function sha1_from_file(filename)
	sha1_encoder:init()
	local ff = assert(io.open(filename, "rb"))
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

-- map path in repo to realpath (replace mountpoint)
function repo:realpath(pathname)
	local mountname = self._mountname
	for _, mpath in ipairs(self._mountname) do
		if pathname == mpath then
			return self._mountpoint[mpath]
		end
		local n = #mpath + 1
		if pathname:sub(1,n) == mpath .. '/' then
			return self._mountpoint[mpath] .. "/" .. pathname:sub(n+1)
		end
	end
	return self._root .. pathname
end

local function list_files(self, filepath)
	local rpath = self:realpath(filepath)
	local files = {}
	for name in fs.dir(rpath) do
		if name:sub(1,1) ~= '.' then	-- ignore .xxx file
			files[name] = true
		end
	end
	if filepath == '' then
		-- root path
		for mountname in pairs(self._mountpoint) do
			if mountname ~= ''  and not mountname:find("/",1,true) then
				files[mountname] = true
			end
		end
	else
		filepath = filepath .. '/'
		local n = #filepath
		for mountname in pairs(self._mountpoint) do
			if mountname:sub(1,n) == filepath then
				local name = mountname:sub(n+1)
				if not name:find("/",1,true) then
					files[name] = true
				end
			end
		end
	end
	return files
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
	local files = list_files(self, filepath)

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
			local filepath = self._repo .. "/" .. hash:sub(1,2) .. "/" .. hash .. ".ref"
			local f = io.open(filepath, "rb")
			if f then
				-- merge ref file
				for line in f:lines() do
					local filename = line:match "^[df] (%S*)"
					if not refset[filename] then
						table.insert(ref, line)
						refset[filename] = true
					end
				end
				f:close()
			end
			table.sort(ref)
			local f = assert(io.open(filepath, "wb"))
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
	local cache = {}
	self._namecache = {}	-- clear cache
	return self:build()
end

function repo:build()
	local cache = {}
	self._namecache[''] = undef
	local roothash = repo_build_dir(self, "", cache, self._namecache)

	repo_write_cache(self, cache)
	repo_write_root(self, roothash)

	return roothash
end

function repo:rebuild()
	self._namecache = {}	-- clear cache
	self:build()
end


--[[
	all path should be absolute path

	{ rootpath,
		xxx = mountxxx,
	}
]]
function repo.init(mount)
	local rootpath = mount[1]
	if not isdir(rootpath) then
		assert(fs.mkdir(rootpath))
	end
	rootpath = addslash(rootpath)
	local mountfile = {}
	for name, path in pairs(mount) do
		if name ~= 1 then
			table.insert(mountfile, string.format("%s:%s", name, path))
		end
	end
	if #mountfile > 0 then
		table.sort(mountfile)
		local f = assert(io.open(rootpath .. ".mount", "wb"))
		f:write(table.concat(mountfile,"\n"))
		f:close()
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
	local m = fs.attributes(rootf, "mode")
	if not isfile(rootf) then
		-- rebuild repo
		local r = repo.new(rootpath)
		r:rebuild()
		-- unlock repo
		r._lock:free()
	end
end

-- make file dirty, would build later
function repo:touch(pathname)
	repeat
		local path = pathname:match "(.*)/"
		if _DEBUG then print("TOUCH", pathname) end
		self._namecache[pathname] = undef
		pathname = path
	until path == nil
end

function repo:touch_path(pathname)
	local namecache = self._namecache
	if pathname == '' then
		-- clear all
		namecache = {}
		return
	end
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

local function remove_ref(filename, name)
	local content = {}
	local f = io.open(filename, "rb")
	if not f then
		return
	end
	for line in f:lines() do
		local n = line:match "^[df] (%S*)"
		if n ~= name then
			table.insert(content, line)
		end
	end
	f:close()
	update_ref(filename, content)
end

local function read_ref(self, hash, conflict)
	local cache = self._namecache
	local filename = refname(self, hash)
	local items = {}
	local needupdate
	for line in io.lines(filename) do
		local name, ts = line:match "[df] (%S*) ?(%d*)"
		if name == nil then
			if _DEBUG then print("INVALID", hash) end
			needupdate = true
		elseif cache[name] then
			if not cache[name].timestamp then
				-- dir conflict, remove later
				conflict[name] = cache[name].hash
			end
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
				cache[name] = { hash = hash }
				table.insert(items, line)
			end
		end
	end
	if needupdate then
		update_ref(filename, items)
	end
end

function repo:index()
	local repo = self._repo
	local conflict = {}
	local namecache = {}
	self._namecache = namecache
	for i = 0, 0xff do
		local refpath = string.format("%s/%02x", repo, i)
		for name in fs.dir(refpath) do
			if name:sub(-4) == ".ref" then
				read_ref(self, name:sub(1,-5), conflict)
			end
		end
	end
	for name,hash in pairs(conflict) do
		namecache[name] = nil
		local filename = refname(self, hash)
		remove_ref(filename, name)
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
	local f = io.open(rfilename, "rb")
	if not f then
		return
	end
	for line in f:lines() do
		local name, timestamp = line:match "f (%S*) (%d*)"
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
		local t, hash, name = line:match "^([df]) (%S*) (%S*)"
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

return repo
