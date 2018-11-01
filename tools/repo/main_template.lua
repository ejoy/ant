
--luacheck: globals iup
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

local fs = require "filesystem"
local projpath = fs.currentdir()

local vfs = require "vfs.vfs"
vfs.open(projpath)

----user code begin
--[[
local testf = io.open(vfs.realpath("engine/assets/mehses/mesh.ozz"))
if testf then
	iup.Message("Info", "found file")
end

local canvas = iup.canvas {
	rastersize = "1024x768",
}

local dlg = iup.dialog {
	canvas,
	title = "vfs project test",
	shrink="yes",	-- logger box should be allow shrink
}

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

iup.MainLoop()
iup.Close()
]]