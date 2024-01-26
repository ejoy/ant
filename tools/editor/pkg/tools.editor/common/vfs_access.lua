local access = {}

local platform = require "bee.platform"
local lfs = require "bee.filesystem"
local mount = dofile "/engine/mount.lua"

local isWindows <const> = platform.os == "windows"

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

access.readmount = mount.read

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

return access
