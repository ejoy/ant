require "runtime.vfsio"
local fs = require "filesystem"
local vfs = require "vfs"

--we assume cwd is ant root folder
local repopath = fs.current_path()
vfs.mount({["engine"] = repopath}, repopath)

-- init local repo
local repo_cachepath = vfs.repopath()
if not fs.exists(repo_cachepath) then
	fs.create_directories(repo_cachepath)
	for i=0,0xff do
		local abspath = repo_cachepath / string.format("%02x", i)
		fs.create_directories(abspath)
	end
end
	