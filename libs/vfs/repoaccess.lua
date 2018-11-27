local access = {}

local fs = require "lfs"
local crypt = require "crypt"

function access.readmount(filename)
	local f = io.open(filename, "rb")
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
		ret[name] = path
	end
	f:close()
	return ret
end

function access.mountname(mountpoint)
	local mountname = {}

	for name, path in pairs(mountpoint) do
		if name ~= '' then
			table.insert(mountname, name)
		end
		mountpoint[name] = path
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
			return repo._mountpoint[mpath] .. "/" .. pathname:sub(n+1)
		end
	end
	return repo._root .. "/" .. pathname
end

function access.list_files(repo, filepath)
	local rpath = access.realpath(repo, filepath)
	local files = {}
	for name in fs.dir(rpath) do
		if name:sub(1,1) ~= '.' then	-- ignore .xxx file
			files[name] = true
		end
	end
	local ignorepaths = rpath .. "/.ignore"
	local f = io.open(ignorepaths, "rb")
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

local function build(plat, source, lk, tmp)
	-- todo: real build
	return true
end

local function filetime(filepath)
	return lfs.attributes(filepath, "modification")
end

local function genhash(repo, tmp)
	local binhash = access.sha1_from_file(tmp)
	local binhash_path = repo._repo .. binhash:sub(1,2) .. "/" .. binhash
	if not os.rename(tmp, binhash_path) then
		os.remove(binhash_path)
		if not os.rename(tmp, binhash_path) then
			return
		end
	end
	return binhash
end

function access.build_from_path(repo, plat, pathname)
	local hash = access.sha1(pathname .. "." .. plat)
	local cache = repo._repo .. hash:sub(1,2) .. "/" .. hash .. ".path"
	local lk = access.realpath(repo, pathname .. ".lk")
	local source = access.realpath(repo, pathname)
	local timestamp = string.format("%s %d %d", pathname, filetime(source), filetime(lk))

	local f = io.open(cache, "rb")
	local binhash
	if f then
		local readline = f:lines()
		local oplat = readline()
		local otimestamp = readline()
		local hash = readline()
		f:close()
		if oplat == plat and otimestamp == timestamp then
			binhash = hash
		end
	end
	if not binhash then
		local tmp = cache .. ".bin"
		if not build(plat, source, lk, tmp) then
			return
		end
		binhash = genhash(repo, tmp)
		if binhash then
			local f = assert(io.open(cache, "wb"))
			f:write(string.format("%s\n%s\n%s", plat, timestamp, binhash))
			f:close()
		end
	end
	return binhash
end

function access.build_from_hash(repo, hash, plat, source_hash, lk_hash)
	local link = repo._repo .. hash:sub(1,2) .. "/" .. hash .. ".link"
	local f = io.open(link, "rb")
	if f then
		local binhash = f:read "a"
		f:close()
		local binpath = repo._repo .. binhash:sub(1,2) .. "/" .. binhash
		local bin = io.open(binpath, "rb")
		if bin then
			bin:close()
			return binpath
		end
	end
	local tmp = link .. ".bin"
	local source_path = repo._repo .. source_hash:sub(1,2) .. "/" .. source_hash
	local lk_path = repo._repo .. lk_hash:sub(1,2) .. "/" .. lk_hash
	assert(build(plat, source_path, lk_path, tmp))
	local binhash = genhash(repo, tmp)
	local f = io.open(link, "wb")
	f:write(binhash)
	f:close()
	return binhash
end

return access
