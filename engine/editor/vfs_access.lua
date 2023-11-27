local access = {}

local platform = require "bee.platform"
local lfs = require "bee.filesystem"
local mount = dofile "/engine/mount.lua"

local isWindows <const> = platform.os == "windows"

access.addmount = mount.add
access.readmount = mount.read

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
			return mountvpath[i] .. pathname:sub(n + 1)
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
