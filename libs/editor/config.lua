local fs = require "filesystem"
local vfs = require "vfs"
local cwd = fs.currentdir()
vfs.mount({	
	['engine/assets']=cwd .. "/assets", 
	['engine/libs'] = cwd .. "/libs"
}, cwd)

-- import custom loadfile/dofile/io.open
require "vfs.fs"