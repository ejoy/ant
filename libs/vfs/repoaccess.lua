local access = {}

local lfs = require "filesystem.local"
local crypt = require "crypt"

function access.repopath(repo, hash, ext)
	if ext then
		return repo._repo /	hash:sub(1,2) / (hash .. ext)
	else
		return repo._repo /	hash:sub(1,2) / hash
	end
end

function access.readmount(filename)
	local f = lfs.open(filename, "rb")
	local ret = {}
	if not f then
		return ret
	end
	for line in f:lines() do
		local name, path = line:match "^%s*(.-)%s+(.-)%s*$"
		if name == nil then
			if not (line:match "^%s*#" or line:match "^%s*$") then
				f:close()
				error ("Invalid .mount file : " .. line)
			end
		end
		path = path:gsub("%s*#.*$","")	-- strip comment
		ret[name] = lfs.path(path)
	end
	f:close()
	return ret
end

function access.mountname(mountpoint)
	local mountname = {}

	for name in pairs(mountpoint) do
		if name ~= '' then
			table.insert(mountname, name)
		end
	end
	table.sort(mountname, function(a,b) return a>b end)
	return mountname
end

function access.realpath(repo, pathname)
	pathname = pathname:match "^/?(.-)/?$"
	local mountnames = repo._mountname
	for _, mpath in ipairs(mountnames) do
		if pathname == mpath then
			return repo._mountpoint[mpath]
		end
		local n = #mpath + 1
		if pathname:sub(1,n) == mpath .. '/' then
			return repo._mountpoint[mpath] / pathname:sub(n+1)
		end
	end
	return repo._root / pathname
end

function access.list_files(repo, filepath)
	local rpath = access.realpath(repo, filepath)
	local files = {}
	for name in rpath:list_directory() do
		local filename = name:filename():string()
		if filename:sub(1,1) ~= '.' then	-- ignore .xxx file
			files[filename] = true
		end
	end
	local ignorepaths = rpath / ".ignore"
	local f = lfs.open(ignorepaths, "rb")
	if f then
		for name in f:lines() do
			files[name] = nil
		end
		f:close()
	end
	filepath = (filepath:match "^/?(.-)/?$") .. "/"
	if filepath == '/' then
		-- root path
		for mountname in pairs(repo._mountpoint) do
			if mountname ~= ''  and not mountname:find("/",1,true) then
				files[mountname] = true
			end
		end
	else
		local n = #filepath
		for mountname in pairs(repo._mountpoint) do
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

-- sha1
local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

function access.sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

local sha1_encoder = crypt.sha1_encoder()

function access.sha1_from_file(filename)
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

local function build(identity, source, lk, tmp)
	local fileconvert = import_package "ant.fileconvert"
	return fileconvert(identity, source, lk, tmp)
end

local function genhash(repo, tmp)
	local binhash = access.sha1_from_file(tmp)
	local binhash_path = access.repopath(repo, binhash)
	if not pcall(lfs.remove, binhash_path) then
		return
	end
	if not pcall(lfs.rename, tmp, binhash_path) then
		return
	end
	return binhash
end

local function ishash(hash)
	return #hash == 40 and not hash:find "[^%da-f]"
end

function access.build_from_file(repo, hash, identity, source_path, lk_path)
	local link = access.repopath(repo, hash, ".link")
	local f = lfs.open(link, "rb")
	if f then
		local binhash = f:read "a"
		f:close()
		if ishash(binhash) then
			return binhash
		end
	end
	local tmp = lfs.path(link:string() .. ".bin")
	if not build(identity, source_path, lk_path, tmp) then
		return
	end
	-- todo: if this source is platform independent, we can generate all the platforms' .link file for the same bin file.
	local binhash = genhash(repo, tmp)
	local lf = lfs.open(link, "wb")
	lf:write(binhash)
	lf:close()
	return binhash
end

local function checkfilehash(repo, plat, source, lk)
	local source_hash = access.sha1_from_file(source)
	local lk_hash = access.sha1_from_file(lk)
	-- NOTICE: see io.lua for the same hash algorithm
	local hash = access.sha1(plat .. source_hash .. lk_hash)
	return access.build_from_file(repo, hash, plat, source, lk)
end

function access.build_from_path(repo, identity, pathname)
	local hash = access.sha1(pathname .. "." .. identity)
	local cache = access.repopath(repo, hash, ".path")
	local lk = access.realpath(repo, pathname .. ".lk")
	local source = access.realpath(repo, pathname)
	local source_time = lfs.last_write_time(source)
	local lk_time = lfs.last_write_time(source)
	if not source_time or not lk_time then
		return
	end
	local timestamp = string.format("%s %d %d", pathname, source_time, lk_time)

	local f = lfs.open(cache, "rb")
	local binhash
	if f then
		local readline = f:lines()
		local oidentity = readline()
		local otimestamp = readline()
		local hash = readline()
		f:close()
		if oidentity == identity and otimestamp == timestamp and ishash(hash) then
			binhash = hash
		end
	end
	if not binhash then
		binhash = checkfilehash(repo, identity, source, lk)
		if binhash then
			local f = assert(lfs.open(cache, "wb"))
			f:write(string.format("%s\n%s\n%s", identity, timestamp, binhash))
			f:close()
		end
	end
	return binhash
end

return access