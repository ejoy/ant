local vfs = {}

local _F	-- firmware dir
local _D	-- vfs dir
local _cache = setmetatable( {} , { __mode = "kv" } )
local _root

-- dir object example :
-- f vfs.txt 90a5c279259fd4e105c4eb8378e9a21694e1e3c4 1533871795

local function root_hash()
	local f = io.open(_D .. "root", "rb")
	if f then
		local hash = f:read "a"
		f:close()
		return (hash:match "[%da-f]+")
	end
end

local function hash_file(hash)
	local realname = _D .. hash:sub(1,2) .. "/" .. hash
	return io.open(realname, "rb")
end

local function dir_object(hash)
	local df = hash_file(hash)
	if df then
		local dir = {}
		for line in df:lines() do
			local type, name, hash, time = line:match "([fd]) ([^ ]+) ([%da-f]+) (%d+)"
			if type == nil then
				print("Invalid dir object", hash, line)
				df:close()
				return
			end
			dir[name] = {
				dir = type == 'd',
				hash = hash,
				time = tonumber(time),
			}
		end
		df:close()
		return dir
	end
end

function vfs.init(firmware, dir)
	local stripe_sep = "(.-)[/\\]*$"
	_F = firmware:gsub(stripe_sep,"%1/")
	_D = dir:gsub(stripe_sep,"%1/")
	_root = root_hash()
end

function vfs.changeroot(hash)
	local f = assert(io.open(_D .. "root", "wb"))
	f:write(hash)
	_root = hash
	f:close()
end

local function fetch_file(hash, fullpath)
	local dir = _cache[hash]
	if not dir then
		dir = dir_object(hash)
		if not dir then
			return false, hash
		end
		_cache[hash] = dir
	end

	local path, name = fullpath:match "^/?([^/]+)/?(.*)"
	local subpath = dir[path]
	if subpath then
		if subpath.dir then
			return fetch_file(subpath.hash, name)
		else
			if name == "" then
				return true, subpath.hash
			end
		end
	end
	-- invalid repo, root change
end

function vfs.open(path)
	if not _root then
		return
	end
	local ok, hash = fetch_file(_root, path)
	if not ok then
		return nil, hash
	end
	local f = io.open(hash, "rb")
	if f then
		return f
	end
	local subpath = path:match("^%.firmware/(.+)")
	if subpath then
		return io.open(_F .. subpath, "rb"), hash
	end
	return nil, hash
end

function vfs.write(hash, content)
	local f = assert(io.open(hash_file(hash), "wb"))
	f:write(content)
	f:close()
end

return vfs
