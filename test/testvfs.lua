dofile "libs/editor.lua"

local fs = require "filesystem.local"

local projpath = fs.mydocs_path() / "antproj"

local vfs = require "vfs"

local success = vfs.open(projpath)
if success then
	print("open proj success, project path : ", projpath)
	print(vfs.realpath("bin/iup.exe"))
end