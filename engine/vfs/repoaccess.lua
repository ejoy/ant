local access = {}

local lfs = require "bee.filesystem"

function access.addmount(repo, path)
	if not lfs.exists(path) then
		return
	end
	for _, value in ipairs(repo._mountpoint) do
		if value:string() == path then
			return
		end
	end
	repo._mountpoint[#repo._mountpoint+1] = lfs.path(path)
end

function access.readmount(repo)
	repo._mountpoint = {}
	local f <close> = assert(io.open((repo._root / ".mount"):string(), "rb"))
	for line in f:lines() do
		local text = line
			:gsub("#.*$","")	-- strip comment
			:gsub("^%s*","")
			:gsub("%s*$","")
			:gsub("%${([^}]*)}", {
			engine = "./",
			project = repo._root:string():gsub("(.-)[/\\]?$", "%1"),
		})
		if text:match "^%s*$" then
			goto continue
		end
		access.addmount(repo, text)
		::continue::
	end
end

function access.realpath(repo, pathname)
	local mountpoint = repo._mountpoint
	for i = #mountpoint, 1, -1 do
		local path = #pathname > 1 and mountpoint[i] / pathname:sub(2) or mountpoint[i]
		if lfs.exists(path) then
			return path
		end
	end
end

local function is_resource(path)
	path = path:string()
	local ext = path:match "[^/]%.([%w*?_%-]*)$"
	if ext ~= "material" and ext ~= "glb"  and ext ~= "texture" then
		return false
	end
	if path:sub(1,8) == "/.build/" then
		return false
	end
	return true
end

local function get_type(path)
	if lfs.is_directory(path) then
		return "dir"
	elseif is_resource(path) then
		return "file"
	elseif lfs.is_regular_file(path) then
		return "file"
	end
end

function access.type(repo, pathname)
	local rpath = access.realpath(repo, pathname)
	if rpath then
		return get_type(rpath)
	end
end

function access.virtualpath(repo, pathname)
	pathname = pathname:string()
	for _, mpath in ipairs(repo._mountpoint) do
		mpath = mpath:string()
		if pathname == mpath then
			return "/"
		end
		local n = #mpath + 1
		if pathname:sub(1,n) == mpath .. '/' then
			return pathname:sub(n)
		end
	end
end

local DefIgnoreFunc <const> = function() end

local function vfsignore(path)
	local f <close> = io.open((path / ".vfs"):string(), "r")
	if not f then
		return DefIgnoreFunc
	end
	local include = {}
	local exclude = {}
	for line in f:lines() do
		local type, name = line:match "^([ie][nx]clude)%s+(.*)$"
		if name then
			if type == "include" then
				include[#include+1] = name
			elseif type == "exclude" then
				exclude[#exclude+1] = name
			end
		end
	end
	return function (v)
		for i = 1, #exclude do
			if v:match(exclude[i]) then
				return true
			end
		end
		for i = 1, #include do
			if v:match(include[i]) then
				return
			end
		end
		return true
	end
end

function access.list_files(repo, pathname)
	local files = {}
	for _, mountpoint in ipairs(repo._mountpoint) do
		local path = mountpoint / pathname:sub(2)
		if lfs.exists(path) then
			local ignore = vfsignore(path)
			for name in lfs.pairs(path) do
				local filename = name:filename():string()
				if filename:sub(1,1) ~= '.' -- ignore .xxx file
					and not ignore(filename)
				then
					files[filename] = "l"
				end
			end
		end
	end

	local list = {}
	local n = 1
	for filename in pairs(files) do
		list[n] = filename
		n = n + 1
	end
	table.sort(list)
	for _,name in ipairs(list) do
		list[name] = files[name]
	end
	return list
end

return access
