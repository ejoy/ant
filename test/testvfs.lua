dofile "libs/init.lua"

local fs = require "filesystem"

local projpath = fs.personaldir() .."/antproj"

local vfs = require "vfs.vfs"

local success = vfs.open(projpath)
if success then
	print("open proj success, project path : ", projpath)
	print(vfs.realpath("bin/iup.exe"))
end