local localfs = require "filesystem.local"
local vfs = require "vfs"
require "vfs.io"

--we assume cwd is ant root folder
local repopath = localfs.current_path()
vfs.mount({["engine"] = repopath}, repopath)

-- init local repo
local repo_cachepath = vfs.repopath()
if not localfs.exists(repo_cachepath) then
	localfs.create_directories(repo_cachepath)
	for i=0,0xff do
		local abspath = repo_cachepath / string.format("%02x", i)
		localfs.create_directories(abspath)
	end
end
	