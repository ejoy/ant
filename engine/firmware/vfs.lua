local vfs = {} ; vfs.__index = vfs

-- dir object example :
-- f vfs.txt 90a5c279259fd4e105c4eb8378e9a21694e1e3c4 1533871795

local function root_hash(self)
	local f = io.open(self.path .. "root", "rb")
	if f then
		local hash = f:read "a"
		f:close()
		return (hash:match "[%da-f]+")
	end
end

function vfs.new(repopath)
	local repo = {
		path = repopath:gsub("[/\\]?$","/") .. ".repo/",
		cache = setmetatable( {} , { __mode = "kv" } ),
		root = nil,
	}
	repo.root = root_hash(repo)
	return setmetatable(repo, vfs)
end

local function dir_object(self, hash)
	local realname = self.path .. hash:sub(1,2) .. "/" .. hash
	local df = io.open(realname, "rb")
	if df then
		local dir = {}
		for line in df:lines() do
			local type, hash, name = line:match "([fd]) ([%da-f]+) (.*)"
			if type then
				dir[name] = {
					dir = type == 'd',
					hash = hash,
				}
			end
		end
		df:close()
		return dir
	end
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

	local path, name = fullpath:match "([^/]*)/?(.*)"
	local subpath = dir[path]
	if subpath then
		if name == "" then
			return true, subpath.hash
		elseif subpath.dir then
			return fetch_file(self, subpath.hash, name)
		end
	end
	-- invalid repo, root change
end

function vfs:list(path)
	local hash
	if path == "" then
		hash = self.root
	else
		local ok, h = fetch_file(self, self.root, path)
		if not ok then
			return false, h
		end
		hash = h
	end
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return false, hash
		end
		self.cache[hash] = dir
	end
	return dir
end

function vfs:changeroot(hash)
	local f = assert(io.open(self.path .. "root", "wb"))
	f:write(hash)
	self.root = hash
	f:close()
end

function vfs:realpath(path)
	if not self.root then
		return
	end
	local ok, hash = fetch_file(self, self.root, path)
	if not ok then
		return nil, hash
	end

	local f_n = self.path .. hash:sub(1,2) .. "/" .. hash
	return f_n, hash
end

function vfs:hashpath(hash)
	return self.path .. hash:sub(1,2) .. "/" .. hash
end

return vfs
