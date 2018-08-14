local errlog, firmware, dir, cfuncs, V = ...

cfuncs = cfuncs()

package.preload.lfs = cfuncs.lfs	-- init lfs

local vfs = assert(loadfile(firmware .. "/vfs.lua"))()
local repo = vfs.new(firmware, dir)
local f = repo:open(".firmware/vfs.lua")	-- try load vfs.lua in vfs
if f then
	local vfs_source = f:read "a"
	f:close()
	vfs = assert(load(vfs_source, "@.firmware/vfs.lua"))()
	repo = vfs.new(firmware, dir)
end

local function readfile(f)
	if f then
		local content = f:read "a"
		f:close()
		return content
	end
end

local bootstrap = readfile(repo:open(".firmware/bootstrap.lua"))

if bootstrap then
	local newboot = load(bootstrap, "@.firmware/bootstrap.lua")
	local selfchunk = string.dump(debug.getinfo(1, "f").func, true)

	if string.dump(newboot, true) ~= selfchunk then
		-- reload bootstrap
		newboot(...)
		return
	end
end

local open = vfs.open

function _LOAD(path, ret)
	local f = open(path)
	if f then
		local content = f:read "a"
		f:close()
		return content
	end
end

_VFS = cfuncs.initvfs(V)	-- init V , store in _G
