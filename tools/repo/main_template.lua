local enginepath = os.getenv("ANTGE")

if enginepath == nil or enginepath == "" then
	local errmsg = "ANTGE environment variable is not define!"
	if iup then
		iup.Message("Error", errmsg)
	else
		print(errmsg)
	end
	
	return
end

dofile(enginepath .. "/libs/init.lua")

local fs = require "lfs"
local projpath = fs.currentdir()

local vfs = require "vfs"
vfs.open(projpath)

local projentry = "project_entry.lua"
if not lfs.exist(projentry) then
	error(string.format("project need add project_entry.lua file to load project"))
end

require(projentry)
