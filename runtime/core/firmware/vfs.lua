local lfs = require "lfs"

local vfs = {} ; vfs.__index = vfs

-- dir object example :
-- f vfs.txt 90a5c279259fd4e105c4eb8378e9a21694e1e3c4 1533871795

local function root_hash(self)
	local f = io.open(self.dpath .. "root", "rb")
	if f then
		local hash = f:read "a"
		f:close()
		return (hash:match "[%da-f]+")
	end
end

function vfs.new(firmware, dir)
	local stripe_sep = "(.-)[/\\]*$"
	local repo = {
		fpath = firmware:gsub(stripe_sep,"%1/"),
		dpath = dir:gsub(stripe_sep,"%1/"),
		cache = setmetatable( {} , { __mode = "kv" } ),
		root = nil,
	}
	repo.root = root_hash(repo)
	return setmetatable(repo, vfs)
end

local function dir_object(self, hash)
	local realname = self.dpath .. hash:sub(1,2) .. "/" .. hash
	local df = io.open(realname, "rb")
	if df then
		local dir = {}
		for line in df:lines() do
			local type, hash, name = line:match "([fd]) ([%da-f]+) ([^ ]+)"
			if type == nil then
				print("Invalid dir object", hash, line)
				df:close()
				return
			end
			dir[name] = {
				dir = type == 'd',
				hash = hash,
			}
		end
		df:close()
		return dir
	end
end

function vfs:changeroot(hash)
	local f = assert(io.open(self.dpath .. "root", "wb"))
	f:write(hash)
	self.root = hash
	f:close()
end

local function fetch_file(self, hash, fullpath)
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return false, hash
		end
		self.cache[hash] = dir
	end

	local path, name = fullpath:match "^/?([^/]+)/?(.*)"
	local subpath = dir[path]
	if subpath then
		if subpath.dir then
			return fetch_file(self, subpath.hash, name)
		else
			if name == "" then
				return true, subpath.hash
			end
		end
	end
	-- invalid repo, root change
end

local function open_from_repo(self, path)
	if not self.root then
		return
	end
	local ok, hash = fetch_file(self, self.root, path)
	if not ok then
		return nil, hash
	end
	local f = io.open(self.dpath .. hash:sub(1,2) .. "/" .. hash, "rb")
	if f then
		return f
	end
	return nil, hash
end

function vfs:hash(path)
	if path == '/' then
		if self.root then
			return true, self.root
		else
			return
		end
	end
	return fetch_file(self, self.root, path)
end

function vfs:open(path)
	local f, hash = open_from_repo(self, path)
	if f then
		return f
	end
	local fpath = path:match("^%.firmware/(.+)")
	if fpath then
		return io.open(self.fpath .. fpath, "rb"), hash
	end

	return nil, hash
end

function vfs:write(hash, content)
	local path = self.dpath .. hash:sub(1,2)
	local m = lfs.attributes(path, "mode")
	if m then
		assert( m == "directory" )
	else
		lfs.mkdir(path)
	end

	local f = assert(io.open(path .. "/" .. hash, "wb"))
	f:write(content)
	f:close()
end

return vfs
