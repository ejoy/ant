local errlog, firmware, dir, cfuncs, V = ...

local vfs = assert(loadfile(firmware .. "/vfs.lua"))()
vfs.init(firmware, dir)
local f = vfs.open(".firmware/vfs.lua")	-- try load vfs.lua in vfs
if f then
	local vfs_source = f:read "a"
	f:close()
	vfs = assert(load(vfs_source, "@.firmware/vfs.lua"))()
	vfs.init(firmware, dir)
end

local function readfile(f)
	if f then
		local content = f:read "a"
		f:close()
		return content
	end
end

local bootstrap = readfile(vfs.open(".firmware/bootstrap.lua"))

if bootstrap then
	local newboot = load(bootstrap, "@.firmware/bootstrap.lua")
	local selfchunk = string.dump(debug.getinfo(1, "f").func, true)

	if string.dump(newboot, true) ~= selfchunk then
		-- reload bootstrap
		newboot(...)
		return
	end
end

cfuncs = cfuncs()

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
