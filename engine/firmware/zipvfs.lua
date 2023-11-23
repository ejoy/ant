local zip = require "zip"

local zipvfs = {}; zipvfs.__index = zipvfs
local CACHESIZE <const> = 8 * 1024 * 1024

function zipvfs.new(config)
	local repo = {
		localpath = config.localpath,
		cachesize = config.cachesize or CACHESIZE,
		cache_hash = {},
	}
	if config.zipbundle then
		repo.zipfile = zip.open(config.zipbundle, "r")
		if not repo.zipfile then
			print("Can't open " .. config.zipbundle)
		else
			repo.cache = zip.reader(repo.zipfile, repo.cachesize)
			repo.backup = {}
		end
	end
	setmetatable(repo, zipvfs)
	return repo
end

function zipvfs:ziproot()
	local zf = self.zipfile
	return zf and zf:readfile "root"
end

function zipvfs:dir(hash)
	local dir = self.cache_hash[hash]
	if dir then
		return dir
	end
	local zf = self.zipfile
	local data = zf and zf:readfile(hash)
	if not data then
		-- todo: use fastio
		local f = io.open(self.localpath .. "/" .. hash, "rb")
		if f then
			data = f:read "a"
			f:close()
		end
	end
	if not data then
		return
	end
	dir = {}
	for line in data:gmatch "[^\r\n]*" do
		local type, name, hash = line:match "^([dfr]) (%S*) (%S*)$"
		if type then
			dir[name] = {
				type = type,
				hash = hash,
			}
		end
	end
	self.cache_hash[hash] = dir
	return dir
end

local function read_backup(self, hash)
	local backup = self.backup
	local n = #backup
	for i = 1, n do
		local c = backup[i]
		local handle = c(hash)
		if handle then
			backup[i] = self.cache
			self.cache = c
			return handle
		end
	end
	local c = zip.reader(self.zipfile, self.cachesize)
	local handle = assert(c(hash))
	backup[n+1] = self.cache
	self.cache = c
	return handle
end

local function open_inzip(self, hash)
	local c = self.cache
	if not c then
		return
	end
	local handle, needsize = c(hash)
	if handle then
		return handle
	end
	if not needsize then
		return
	end
	if needsize > CACHESIZE then
		c = zip.reader(self.zipfile, needsize)
		self.backup[#self.backup + 1] = c
	else
		read_backup(self, hash)
	end
end

function zipvfs:open(hash)
	local c = open_inzip(self, hash)
	if not c then
		-- todo: use fastio
		local f = io.open(self.localpath .. "/" .. hash, "rb")
		if not f then
			return
		end
		local data = f:read "a"
		c = zip.reader_new(data)
		f:close()
	end
	return c
end

return zipvfs
