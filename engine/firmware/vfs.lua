local vfs = {} ; vfs.__index = vfs

local uncomplete = {}

-- dir object example :
-- f vfs.txt 90a5c279259fd4e105c4eb8378e9a21694e1e3c4 1533871795

local function read_history(self)
	local history = {}
	local f = io.open(self.path .. "root", "rb")
	if f then
		for hash in f:lines() do
			history[#history+1] = hash:match "[%da-f]+"
		end
		f:close()
	end
	return history
end

local function update_history(self, new)
	local history = read_history(self)
	for i, h in ipairs(history) do
		if h == new then
			table.remove(history, i)
			table.insert(history, 1, h)
			return history
		end
	end
	table.insert(history, 1, new)
	history[11] = nil
	return history
end

local function root_hash(self)
	local f = io.open(self.path .. "root", "rb")
	if f then
		local hash = f:read "l"
		f:close()
		return (hash:match "[%da-f]+")
	end
end

function vfs.new(repopath)
	local repo = {
		path = repopath:gsub("[/\\]?$","/") .. ".repo/",
		cache = {},--setmetatable( {} , { __mode = "kv" } ),
		root = nil,
	}
	setmetatable(repo, vfs)
	local hash = root_hash(repo)
	if hash then
		repo:changeroot(hash)
	end
	return repo
end

local function dir_object(self, hash)
	local realname = self.path .. hash:sub(1,2) .. "/" .. hash
	local df = io.open(realname, "rb")
	if df then
		local dir = {}
		for line in df:lines() do
			local type, hash, name = line:match "([dfr]) (%S*) (.*)"
			if type then
				dir[name] = {
					type = type,
					hash = hash,
				}
			end
		end
		df:close()
		return dir
	end
end

local ListSuccess <const> = 1
local ListFailed <const> = 2
local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

local function fetch_file(self, hash, fullpath, parent)
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return ListNeedGet, hash
		end
		self.cache[hash] = dir
	end

	local path, name = fullpath:match "/?([^/]+)/?(.*)"
	local subpath = dir[path]
	if subpath then
		if name == "" then
			if subpath.type == 'r' then
				local res = parent.."/"..path
				local h = self.resource[res]
				if h then
					return ListSuccess, h
				end
				return ListNeedResource, res
			else
				return ListSuccess, subpath.hash
			end
		else
			if subpath.type == 'd' then
				return fetch_file(self, subpath.hash, name, parent.."/"..path)
			elseif subpath.type == 'r' then
				local res = parent.."/"..path
				local h = self.resource[res]
				if h then
					return fetch_file(self, h, name, res)
				end
				return ListNeedResource, res
			end
		end
	end
	-- invalid repo, root change
	return ListFailed
end

function vfs:list(path, hash)
	hash = hash or self.root
	if path ~= "" then
		local r, h = fetch_file(self, hash, path, "")
		if r ~= ListSuccess then
			return nil, r, h
		end
		hash = h
	end
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return nil, ListNeedGet, hash
		end
		self.cache[hash] = dir
	end
	return dir
end

function vfs:updatehistory(hash)
	local history = update_history(self, hash)
	local f <close> = assert(io.open(self.path .. "root", "wb"))
	f:write(table.concat(history, "\n"))
end

function vfs:changeroot(hash)
	self.root = hash
	self.resource = {}
	local path = self:hashpath(hash)..".resource"
	do
		local f <close> = io.open(path, "rb")
		if f then
			for line in f:lines() do
				local hash, name = line:match "([%da-f]+) (.*)"
				if hash then
					self.resource[name] = hash
				end
			end
		end
	end
end

function vfs:get_resource(name)
	return self.resource[name]
end

function vfs:set_resource(name, hash)
	self.resource[name] = hash
	local path = self:hashpath(self.root)..".resource"
	local f <close> = assert(io.open(path, "ab"))
	f:write(("%s %s\n"):format(hash, name))
end

function vfs:realpath(path)
	if not self.root then
		return
	end
	local ok, hash = fetch_file(self, self.root, path, "")
	if not ok then
		return nil, hash
	end

	local f_n = self.path .. hash:sub(1,2) .. "/" .. hash
	return f_n, hash
end

function vfs:hashpath(hash)
	return self.path .. hash:sub(1,2) .. "/" .. hash
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
	local hashpath = self:hashpath(hash)
	if writefile(hashpath, data) then
		return true
	end
end

function vfs:write_file(hash, size)
	uncomplete[hash] = { size = tonumber(size), offset = 0 }
end

function vfs:write_slice(hash, offset, data)
	offset = tonumber(offset)
	local hashpath = self:hashpath(hash)
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
