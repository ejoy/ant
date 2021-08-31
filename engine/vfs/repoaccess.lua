local access = {}

local lfs = require "filesystem.local"

local function raw_dofile(path)
	local file <close> = assert(io.open(path, 'rb'))
	local func = assert(load(file:read 'a', '@' .. path))
	return func()
end

local function load_package(path)
    if not lfs.is_directory(path) then
        error(('`%s` is not a directory.'):format(path:string()))
    end
    local cfgpath = path / "package.lua"
    if not lfs.exists(cfgpath) then
        error(('`%s` does not exist.'):format(cfgpath:string()))
    end
    local config = raw_dofile(cfgpath:string())
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

function access.addmount(repo, name, path)
	local p = repo._mountpoint[name]
	if p == nil then
		repo._mountpoint[name] = lfs.path(path)
		repo._mountname[#repo._mountname+1] = name
	elseif p:string() == path then
	else
		error("Duplicate mount: " ..name)
	end
end

function access.readmount(repo)
	local mountpoint = {}
	local mountname = {}
	local function addmount(name, path)
		mountpoint[name] = path
		mountname[#mountname+1] = name
	end
	local f <close> = assert(lfs.open(repo._root / ".mount", "rb"))
	for line in f:lines() do
		local name, path = line:match "^%s*(.-)%s+(.-)%s*$"
		if name == nil then
			if not (line:match "^%s*#" or line:match "^%s*$") then
				error ("Invalid .mount file : " .. line)
			end

			goto continue
		end
		path = path:gsub("%s*#.*$","")	-- strip comment
		path = path:gsub("%${([^}]*)}", {
			project = repo._root:string():gsub("(.-)[/\\]?$", "%1")
		})
		path = lfs.absolute(lfs.path(path))
		if name == '@pkg-one' then
			local pkgname = load_package(path)
			addmount('pkg/'..pkgname, path)
		elseif name == '@pkg' then
			for pkgpath in path:list_directory() do
				if not pkgpath:string():match ".DS_Store" then
					local pkgname = load_package(pkgpath)
					addmount('pkg/'..pkgname, pkgpath)
				end
			end
		else
			addmount(name, path)
		end

		::continue::
	end
	table.sort(mountname)
	repo._mountname = mountname
	repo._mountpoint = mountpoint
end

function access.realpath(repo, pathname)
	pathname = pathname:match "^/?(.-)/?$"
	local mountnames = repo._mountname
	for i = #mountnames, 1, -1 do
		local mpath = mountnames[i]
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
	-- TODO: ipairs
	for name, mpath in pairs(repo._mountpoint) do
		mpath = mpath:string()
		if pathname == mpath then
			return name
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
				files[filename] = "l"
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
			files[name] = "v"
		end
	else
		local n = #filepath
		for mountname in pairs(repo._mountpoint) do
			if mountname:sub(1,n) == filepath then
				local name = mountname:sub(n+1):match "^([^/]+)/?"
				files[name] = "v"
			end
		end
	end
	return files
end

return access
