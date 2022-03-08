local access = {}

local lfs = require "bee.filesystem"

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

function access.addmount(repo, name, path)
	local p = repo._mountpoint[name]
	if p == nil then
		repo._mountpoint[name] = lfs.path(path)
		repo._mountname[#repo._mountname+1] = name
	elseif p:string() == path:string() then
	else
		error("Duplicate mount: " ..name)
	end
end

local function split(str)
    local r = {}
    str:gsub('[^%s]+', function (w) r[#r+1] = w end)
    return r
end

function access.readmount(repo)
	local mountpoint = {}
	local mountname = {}
	local function addmount(name, path)
		if name:sub(1,1) ~= "/" then
			name = "/"..name
		end
		if name:sub(-1) == "/" then
			name = name:sub(1,-2)
		end
		mountpoint[name] = path
		mountname[#mountname+1] = name
	end
	local f <close> = assert(io.open((repo._root / ".mount"):string(), "rb"))
	for line in f:lines() do
		local function assert_syntax(cond)
			if not cond then
				error("Invalid .mount file : " .. line, 2)
			end
		end
		local text = line
			:gsub("#.*$","")	-- strip comment
			:gsub("%${([^}]*)}", {
			project = repo._root:string():gsub("(.-)[/\\]?$", "%1")
		})
		if text:match "^%s*$" then
			goto continue
		end
		local tokens = split(text)
		assert_syntax(#tokens >= 1)
		local name = tokens[1]
		if name:sub(1, 1) == "@" then
			if name == '@pkg-one' then
				assert_syntax(#tokens == 2)
				local path = lfs.absolute(lfs.path(tokens[2]))
				local pkgname = load_package(path)
				addmount('/pkg/'..pkgname, path)
			elseif name == '@pkg' then
				assert_syntax(#tokens == 2)
				local path = lfs.absolute(lfs.path(tokens[2]))
				for pkgpath in lfs.pairs(path) do
					if not pkgpath:string():match ".DS_Store" then
						local pkgname = load_package(pkgpath)
						addmount('/pkg/'..pkgname, pkgpath)
					end
				end
			else
				assert_syntax(false)
			end
		else
			assert_syntax(#tokens == 2)
			local path = lfs.absolute(lfs.path(tokens[2]))
			addmount(name, path)
		end
		::continue::
	end
	table.sort(mountname)
	repo._mountname = mountname
	repo._mountpoint = mountpoint
end

function access.realpath(repo, pathname)
	if pathname:sub(1,1) ~= "/" then
		--TODO
		if pathname:sub(1,7) ~= "engine/" then
			log.warn(("Use relative path as absolute path: `%s`"):format(pathname))
		end
		pathname = "/"..pathname
	end
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
	if rpath then
		if lfs.exists(rpath) then
			for name in lfs.pairs(rpath) do
				local filename = name:filename():string()
				if filename:sub(1,1) ~= '.' then	-- ignore .xxx file
					files[filename] = "l"
				end
			end
		end
	end
	if filepath == '/' then
		-- root path
		for mountname in pairs(repo._mountpoint) do
			if mountname ~= "" then
				local name = mountname:match "^/([^/]+)/?"
				files[name] = "v"
			end
		end
	else
		local n = #filepath
		for mountname in pairs(repo._mountpoint) do
			if mountname:sub(1,n) == filepath then
				local name = mountname:sub(n):match "^/([^/]+)/?"
				files[name] = "v"
			end
		end
	end
	return files
end

return access
