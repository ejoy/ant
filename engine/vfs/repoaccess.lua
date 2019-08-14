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
	if repo._loc then
		local rpath = access.realpath(repo, path)
		return access.sha1_from_file(rpath)
	else
		if not repo._internal then
			repo._internal = vfsinternal.new(repo._root:string())
		end
		local _, hash = repo._internal:realpath(path)
		return hash
	end
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

local function readfile(filename)
	local f = assert(lfs.open(filename))
	local str = f:read "a"
	f:close()
	return str
end

local function writefile(filename, str)
	lfs.create_directories(filename:parent_path())
	local f = assert(lfs.open(filename, "wb"))
	f:write(str)
	f:close()
end

local function rawtable(filename)
	local env = {}
	local r = assert(lfs.loadfile(filename, "t", env))
	r()
	return env
end

local function calchash(depends)
	sha1_encoder:init()
	for _, dep in ipairs(depends) do
		sha1_encoder:update(dep[1])
	end
	return sha1_encoder:final():gsub(".", byte2hex)
end

local function prebuild(repo, plat, sourcefile, buildfile, deps)
	local depends = {}
	for _, name in ipairs(deps) do
		local vname = access.virtualpath(repo, lfs.relative(name, lfs.current_path()))
		if vname then
			depends[#depends+1] = {access.sha1_from_file(name), lfs.last_write_time(name), vname}
		else
			print("MISSING DEPEND", name)
		end
	end

	local lkfile = sourcefile .. ".lk"
	local w = {}
	local dephash = calchash(depends)
	w[#w+1] = ("identity = %q"):format(plat)
	w[#w+1] = ("dephash = %q"):format(dephash)
	w[#w+1] = "depends = {"
	for _, dep in ipairs(depends) do
		w[#w+1] = ("  {%q, %d, %q},"):format(dep[1], dep[2], dep[3])
	end
	w[#w+1] = "}"
	w[#w+1] = readfile(lkfile)
	writefile(buildfile, table.concat(w, "\n"))
	return dephash
end

local function add_ref(repo, file, hash)
	local vfile = ".cache" .. file:string():sub(#repo._cache:string()+1)
	local timestamp = lfs.last_write_time(file)
	local info = ("f %s %d"):format(vfile, timestamp)

	local reffile = access.repopath(repo, hash) .. ".ref"
	if not lfs.exists(reffile) then
		local f = assert(lfs.open(reffile, "wb"))
		f:write(info)
		f:close()
		return
	end
	
	local w = {}
	for line in lfs.lines(reffile) do
		local name, ts = line:match "^[df] (.-) ?(%d*)$"
		if name == vfile and tonumber(ts) == timestamp then
			return
		else
			w[#w+1] = line
		end
	end
	w[#w+1] = info
	local f = lfs.open(reffile, "wb")
	f:write(table.concat(w, "\n"))
	f:close()
end

local function link(repo, srcfile, identity, buildfile)
	local param
	if lfs.exists(buildfile) then
		param = rawtable(buildfile)
		local cpath = repo._cache / param.dephash:sub(1,2) / param.dephash
		if lfs.exists(cpath) then
			local binhash = readfile(cpath..".hash")
			add_ref(repo, cpath, binhash)
			return cpath, binhash
		end
		identity = param.identity
		srcfile = access.realpath(repo, param.depends[1][3])
	else
		param = rawtable(srcfile .. ".lk")
	end
	local fs = import_package "ant.fileconvert"
	local deps = fs.prelink(param, srcfile)
	if deps then
		local dephash = prebuild(repo, identity, srcfile, buildfile, deps)
		local cpath = repo._cache / dephash:sub(1,2) / dephash
		if lfs.exists(cpath) then
			local binhash = readfile(cpath..".hash")
			add_ref(repo, cpath, binhash)
			return cpath, binhash
		end
		local dstfile = repo._repo / "tmp.bin"
		local ok = fs.link(param, identity, srcfile, dstfile)
		if not ok then
			return
		end
		if not pcall(lfs.rename, dstfile, cpath) then
			pcall(lfs.remove, dstfile)
			return
		end
		local binhash = access.sha1_from_file(cpath)
		writefile(cpath..".hash", binhash)
		add_ref(repo, cpath, binhash)
		return cpath, binhash
	else
		local dstfile = repo._repo / "tmp.bin"
		local deps = fs.link(param, identity, srcfile, dstfile)
		if not deps then
			return
		end
		local dephash = prebuild(repo, identity, srcfile, buildfile, deps)
		local cpath = repo._cache / dephash:sub(1,2) / dephash
		if not pcall(lfs.remove, cpath) then
			pcall(lfs.remove, dstfile)
			return
		end
		if not pcall(lfs.rename, dstfile, cpath) then
			pcall(lfs.remove, dstfile)
			return
		end
		local binhash = access.sha1_from_file(cpath)
		writefile(cpath..".hash", binhash)
		add_ref(repo, cpath, binhash)
		return cpath, binhash
	end
end

function access.link_loc(repo, identity, path)
	local srcfile = access.realpath(repo, path)
	local pathhash = access.sha1(path)
	local buildfile = repo._build / pathhash / srcfile:filename() .. identity
	return link(repo, srcfile, identity, buildfile)
end

function access.link(repo, identity, path, buildhash)
	local srcfile = access.realpath(repo, path)
	local buildfile
	if buildhash then
		buildfile = repo:hash(buildhash)
	end
	if not buildfile then
		local pathhash = access.sha1(path)
		buildfile = repo._build / pathhash / srcfile:filename() .. identity
	end
	local dstfile, binhash = link(repo, srcfile, identity, buildfile)
	if not dstfile then
		return
	end
	if not buildhash then
		buildhash = access.sha1_from_file(buildfile)
	end
	return binhash, buildhash
end

function access.check_build(repo, buildfile)
	for _, dep in ipairs(rawtable(buildfile).depends) do
		local timestamp, filename = dep[2], dep[3]
		local realpath = access.realpath(repo, filename)
		if not realpath or not lfs.exists(realpath)  or timestamp ~= lfs.last_write_time(realpath) then
			lfs.remove(buildfile)
			return false
		end
	end
	return true
end

function access.clean_build(repo, identity, srcpath)
	local srcfile = access.realpath(repo, srcpath)
	if not srcfile then
		return
	end
	local pathhash = access.sha1(srcpath)
	local buildfile = repo._build / pathhash / srcfile:filename() .. identity
	lfs.remove(buildfile)
end

return access
