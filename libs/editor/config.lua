local fs = require "filesystem"
local vfs = require "vfs"
local cwd = fs.currentdir()
vfs.mount({	
	['engine/assets']=cwd .. "/assets", 
	['engine/libs'] = cwd .. "/libs"
}, cwd)

local vfsutil = require "vfs.util"
vfsutil.open = vfsutil.local_open

local nlf = loadfile
loadfile = function (filename)
	local realpath = vfs.realpath(filename) 
	return nlf(realpath)
end

local ndf = dofile
dofile = function (filename)
	local realpath = vfs.realpath(filename)
	return ndf(realpath)
end