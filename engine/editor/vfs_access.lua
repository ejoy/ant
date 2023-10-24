local access = {}

local platform = require "bee.platform"
local lfs = require "bee.filesystem"
local datalist = require "datalist"

local isWindows <const> = platform.os == "windows"

local MountConfig <const> = [[
mount:
    /engine/ %engine%/engine
    /pkg/    %engine%/pkg
    /        %project%
    /        %project%/mod
]]

local function loadmount(repo)
	local f <close> = io.open((repo._root / ".mount"):string(), "rb")
	if f then
		local cfg = datalist.parse(f:read "a")
		if cfg then
			return cfg
		end
	end
	return datalist.parse(MountConfig)
end

function access.addmount(repo, vpath, lpath)
	if not lfs.exists(lpath) then
		return
	end
	assert(vpath:sub(1,1) == "/")
	for _, value in ipairs(repo._mountlpath) do
		if value:string() == lpath then
			return
		end
	end
	repo._mountvpath[#repo._mountvpath+1] = vpath
	repo._mountlpath[#repo._mountlpath+1] = lfs.absolute(lpath):lexically_normal()
end

function access.readmount(repo)
	local cfg = loadmount(repo)
	repo._mountvpath = {}
	repo._mountlpath = {}
	for i = 1, #cfg.mount, 2 do
		local vpath, lpath = cfg.mount[i], cfg.mount[i+1]
		access.addmount(repo, vpath, lpath:gsub("%%([^%%]*)%%", {
			engine = lfs.current_path():string(),
			project = repo._root:string():gsub("(.-)[/\\]?$", "%1"),
		}))
	end
end

function access.realpath(repo, pathname)
	local mountvpath = repo._mountvpath
	local mountlpath = repo._mountlpath
	for i = #mountlpath, 1, -1 do
		if pathname:sub(1, #mountvpath[i]) == mountvpath[i] then
			local path = mountlpath[i] / pathname:sub(1 + #mountvpath[i])
			if lfs.exists(path) then
				return path
			end
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
		return "dir"
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

local path_eq; do
	if isWindows then
		function path_eq(a, b)
			return a:lower() == b:lower()
		end
	else
		function path_eq(a, b)
			return a == b
		end
	end
end

function access.virtualpath(repo, pathname)
	pathname = lfs.absolute(pathname):lexically_normal():string()
	local mountvpath = repo._mountvpath
	local mountlpath = repo._mountlpath
	for i = #mountlpath, 1, -1 do
		local mpath = mountlpath[i]:string()
		if path_eq(pathname, mpath) then
			return mountvpath[i]
		end
		local n = #mpath + 1
		if path_eq(pathname:sub(1,n), mpath .. '/') then
			return mountvpath[i] .. pathname:sub(n)
		end
	end
end

function access.list_files(repo, pathname)
	local files = {}
	local mountvpath = repo._mountvpath
	local mountlpath = repo._mountlpath
	for i = #mountlpath, 1, -1 do
		if pathname:sub(1, #mountvpath[i]) == mountvpath[i] then
			local path = mountlpath[i] / pathname:sub(1 + #mountvpath[i])
			if lfs.is_directory(path) then
				for name, status in lfs.pairs(path) do
					local filename = name:filename():string()
					if filename:sub(1,1) ~= "." then
						files[filename] = status
					end
				end
			end
		end
	end
	return files
end

return access
