dofile "libs/init.lua"

local fs = require "lfs"
local util = require "filesystem.util"

local projpath = util.personaldir() .."/antproj"

local vfs = require "vfs.vfs"

local success = vfs.open(projpath)
if success then
	print("open proj success, project path : ", projpath)
	print(vfs.realpath("bin/iup.exe"))
end