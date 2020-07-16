local access = {}

local lfs = require "filesystem.local"

local function load_package(path)
    if not lfs.is_directory(path) then
        error(('`%s` is not a directory.'):format(path:string()))
    end
    local cfgpath = path / "package.lua"
    if not lfs.exists(cfgpath) then
        error(('`%s` does not exist.'):format(cfgpath:string()))
    end
    local config = dofile(cfgpath:string())
    for _, field in ipairs {'name'} do
        if not config[field] then
            error(('Missing `%s` field in `%s`.'):format(field, cfgpath:string()))
        end
    end
    return config.name
end

local function split(str)
    local r = {}
    str:gsub('[^/]*', function (w) r[#r+1] = w end)
    return r
end

function access.readmount(filename)
	local mountpoint = {}
	local mountname = {}
	local dir = {}
	local function addmount(name, path)
		mountpoint[name] = path
		mountname[#mountname+1] = name
		local dirlst = split(name)
		for i = 1, #dirlst do
			dir[table.concat(dirlst, "/", 1, i)] = true
		end
	end
	local f <close> = assert(lfs.open(filename, "rb"))
	for line in f:lines() do
		local name, path = line:match "^%s*(.-)%s+(.-)%s*$"
		if name == nil then
			if not (line:match "^%s*#" or line:match "^%s*$") then
				error ("Invalid .mount file : " .. line)
			end
		end
		path = lfs.path(path:gsub("%s*#.*$",""))	-- strip comment
		if name == '@pkg-one' then
			local pkgname = load_package(path)
			addmount('pkg/'..pkgname, path)
		elseif name == '@pkg' then
			for pkgpath in path:list_directory() do
				local pkgname = load_package(pkgpath)
				addmount('pkg/'..pkgname, pkgpath)
			end
		else
			addmount(name, path)
		end
	end
	table.sort(mountname)
	return mountpoint, mountname, dir
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
			local name = mountname:match "^([^/]+)/?"
			files[name] = true
		end
	else
		local n = #filepath
		for mountname in pairs(repo._mountpoint) do
			if mountname:sub(1,n) == filepath then
				local name = mountname:sub(n+1):match "^([^/]+)/?"
				files[name] = true
			end
		end
	end
	return files
end

return access
