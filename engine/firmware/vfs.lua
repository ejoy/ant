local fastio = require "fastio"
local zip = require "zip"

local function sha1(str)
	return fastio.str2sha1(str)
end

local vfs = {} ; vfs.__index = vfs
local CACHESIZE <const> = 8 * 1024 * 1024

local uncomplete = {}

local function readroot(self)
	print("[vfs] slot:", self.slot)
	local f = io.open(self.localpath .. "root" .. self.slot, "rb")
	if f then
		local root = f:read "l"
		local ziproot = f:read "l"
		f:close()
		if ziproot == self.ziproot then
			print("[vfs] root:", ziproot)
			return root
		end
		print(("[vfs] updated local:%s zip:%s"):format(ziproot, self.ziproot))
		print("[vfs] remove local cache.")
		os.remove(self.localpath .. "root" .. self.slot)
	else
		print("[vfs] slot is empty")
	end
	return self.ziproot
end

local function updateroot(self, hash)
	local f <close> = assert(io.open(self.localpath .. "root" .. self.slot, "wb"))
	f:write(hash)
	f:write "\n"
	f:write(self.ziproot)
end

function vfs:init(hash)
	if hash then
		updateroot(self, hash)
		local res = self.resource
		self:changeroot(hash)
		return res
	end
	if self.root ~= nil then
		return
	end
	hash = readroot(self)
	if hash then
		self:changeroot(hash)
	else
		error("No history root")
	end
end

function vfs.new(config)
	local repo = {
		slot = config.slot,
		bundlepath = config.bundlepath,
		localpath = config.localpath,
		cachesize = config.cachesize or CACHESIZE,
		resource = {},
		cache_hash = {},
		cache_dir = {},
		cache_file = {},
		root = nil,
		ziproot = "",
	}
	local zipfile = zip.open(repo.bundlepath.."00.zip", "r")
	if not zipfile then
		print("Can't open " .. repo.bundlepath .. "00.zip")
	else
		repo.zipfile = zipfile
		repo.zipreader = zip.reader(zipfile, repo.cachesize)
		repo.ziproot = fastio.readall_s(repo.bundlepath .. "00.hash")
	end
	setmetatable(repo, vfs)
	return repo
end

function vfs:dir(hash)
	local dir = self.cache_hash[hash]
	if dir then
		return dir
	end
	local zf = self.zipfile
	local data = zf and zf:readfile(hash)
	if not data then
		data = fastio.readall_s_noerr(self.localpath .. "/" .. hash)
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

function vfs:open(hash)
	if self.zipreader then
		local c = self.zipreader(hash)
		if c then
			return c
		end
	end
	return fastio.readall_v_noerr(self.localpath .. "/" .. hash)
end

local function get_cachepath(setting, name)
	name = name:lower()
	local filename = name:match "[/]?([^/]*)$"
	local ext = filename:match "[^/]%.([%w*?_%-]*)$"
	local hash = sha1(name)
	return ("/res/%s/%s/%s_%s/"):format(setting, ext, filename, hash)
end

local ListSuccess <const> = 1
local ListFailed <const> = 2
local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

local fetch_file

local function fetch_resource(self, fullpath)
	local h = self.resource[fullpath]
	if h then
		return ListSuccess, h
	end
	local cachepath = get_cachepath(self.setting, fullpath)
	if cachepath then
		local r, h = fetch_file(self, self.root, cachepath)
		if r ~= ListFailed then
			return r, h
		end
	end
	return ListNeedResource, fullpath
end

function fetch_file(self, hash, fullpath)
	local dir = self:dir(hash)
	if not dir then
		return ListNeedGet, hash
	end

	local path, name = fullpath:match "^/([^/]+)(/.*)$"
	local subpath = dir[path]
	if subpath then
		if name == "/" then
			if subpath.type == 'r' then
				return fetch_resource(self, subpath.hash)
			else
				return ListSuccess, subpath.hash
			end
		else
			if subpath.type == 'd' then
				return fetch_file(self, subpath.hash, name)
			elseif subpath.type == 'r' then
				local r, h = fetch_resource(self, subpath.hash)
				if r ~= ListSuccess then
					return r, h
				end
				return fetch_file(self, h, name)
			end
		end
	end
	-- invalid repo, root change
	return ListFailed
end

function vfs:list(path)
	local hash = self.cache_dir[path]
	if not hash then
		local r
		r, hash = fetch_file(self, self.root, path)
		if r ~= ListSuccess then
			return nil, r, hash
		end
		self.cache_dir[path] = hash
	end
	local dir = self:dir(hash)
	if not dir then
		return nil, ListNeedGet, hash
	end
	return dir
end

function vfs:changeroot(hash)
	self.root = hash
	self.resource = {}
	self.cache_dir = { ["/"] = hash }
	self.cache_file = {}
end

function vfs:resource_setting(setting)
	self.setting = setting
end

function vfs:add_resource(name, hash)
	self.resource[name] = hash
end

local function writefile(filename, data)
	local temp = filename .. ".download"
	local f = io.open(temp, "wb")
	if not f then
		print("Can't write to", temp)
		return
	end
	f:write(data)
	f:close()
	if not os.rename(temp, filename) then
		os.remove(filename)
		if not os.rename(temp, filename) then
			print("Can't rename", filename)
			return false
		end
	end
	return true
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function vfs:write_blob(hash, data)
	local hashpath = self.localpath .. hash
	if writefile(hashpath, data) then
		return true
	end
end

function vfs:write_file(hash, size)
	uncomplete[hash] = { size = tonumber(size), offset = 0 }
end

function vfs:write_slice(hash, offset, data)
	offset = tonumber(offset)
	local hashpath = self.localpath .. hash
	local tempname = hashpath .. ".download"
	local f = io.open(tempname, "ab")
	if not f then
		print("Can't write to", tempname)
		return
	end
	local pos = f:seek "end"
	if pos ~= offset then
		f:close()
		f = io.open(tempname, "r+b")
		if not f then
			print("Can't modify", tempname)
			return
		end
		f:seek("set", offset)
	end
	f:write(data)
	f:close()
	local filedesc = uncomplete[hash]
	if filedesc then
		local last_offset = filedesc.offset
		if offset ~= last_offset then
			print("Invalid offset", hash, offset, last_offset)
		end
		filedesc.offset = last_offset + #data
		if filedesc.offset == filedesc.size then
			-- complete
			uncomplete[hash] = nil
			if not os.rename(tempname, hashpath) then
				-- may exist
				os.remove(hashpath)
				if not os.rename(tempname, hashpath) then
					print("Can't rename", hashpath)
				end
			end
			return true
		end
	else
		print("Offset without header", hash, offset)
	end
end

return vfs
