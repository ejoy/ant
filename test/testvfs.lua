dofile "libs/editor.lua"

local lfs = require "filesystem.local"

local projpath = lfs.mydocs_path() / "antproj"

local vfs = require "vfs"

local success = vfs.open(projpath)
if success then
	print("open proj success, project path : ", projpath)
	print(vfs.realpath("bin/iup.exe"))
end