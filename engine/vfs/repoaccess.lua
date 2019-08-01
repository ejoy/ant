local access = {}

local lfs = require "filesystem.local"
local vfsinternal = require "firmware.vfs"
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
		path = lfs.path(path:gsub("%s*#.*$",""))	-- strip comment
		if name == '@pkg-one' then
			local pm = require "antpm"
			local pkgname = pm.load_package(path)
			ret['pkg/'..pkgname] = path
		elseif name == '@pkg' then
			local pm = require "antpm"
			local pkgs = pm.load_packages(path)
			for pkgname, pkgpath in pairs(pkgs) do
				ret['pkg/'..pkgname] = pkgpath
			end
		else
			ret[name] = path
		end
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

function access.virtualpath(repo, pathname)
	pathname = pathname:string()
	local mountpoints = repo._mountpoint
	-- TODO: ipairs
	for name, mpath in pairs(mountpoints) do
		mpath = mpath:string()
		if pathname == mpath then
			return repo._mountname[mpath]
		end
		local n = #mpath + 1
		if pathname:sub(1,n) == mpath .. '/' then
			return name .. '/' .. pathname:sub(n+1)
		end
	end
end

function access.hash(repo, path)
	local rpath = access.realpath(repo, path)
	return access.sha1_from_file(rpath)
	--if not repo._internal then
	--	repo._internal = vfsinternal.new(repo._repo:string())
	--end
	--local _, hash = repo._internal:realpath(path)
	--return hash
end

function access.list_files(repo, filepath)
	local rpath = access.realpath(repo, filepath)
	local files = {}
	if lfs.exists(rpath) then
		for name in rpath:list_directory() do
			local filename = name:filename():string()
			if filename:sub(1,1) ~= '.' then	-- ignore .xxx file
				files[filename] = true
			end
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

local function checkcache(repo, linkfile)
	local f = lfs.open(linkfile, "rb")
	if f then
		local binhash = f:read "l"
		for line in f:lines() do
			local hash, name = line:match "([%da-f]+) (.*)"
			local realhash = access.hash(repo, name)
			if realhash ~= hash then
				f:close()
				return
			end
		end
		f:seek('set', 0)
		local cache = f:read "a"
		f:close()
		return binhash, cache
	end
end

function access.build_from_file(repo, hash, identity, source_path)
	local linkfile = access.repopath(repo, hash, ".link")
	local binhash, cache = checkcache(repo, linkfile)
	if binhash then
		return binhash, cache
	end
	local dstfile = linkfile .. ".bin"
	local build = import_package "ant.fileconvert"
	local deps = build(identity, access.realpath(repo, source_path), dstfile)
	if not deps then
		return
	end
	local binhash = access.sha1_from_file(dstfile)
	local binhash_path = access.repopath(repo, binhash)
	if not pcall(lfs.remove, binhash_path) then
		return
	end
	if not pcall(lfs.rename, dstfile, binhash_path) then
		return
	end
	local s = {}
	s[#s+1] = binhash
	for _, depfile in ipairs(deps) do
		local vpath = access.virtualpath(repo, depfile)
		if vpath then
			s[#s+1] = ("%s %s"):format(access.sha1_from_file(depfile), vpath)
		end
	end
	local cache = table.concat(s, "\n")
	local lf = lfs.open(linkfile, "wb")
	lf:write(cache)
	lf:close()
	return binhash, cache
end

return access
