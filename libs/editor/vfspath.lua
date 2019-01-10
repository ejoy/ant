require "runtime.vfsio"
local fs = require "filesystem"
local repopath = fs.current_path()

local vfs = require "vfs"

if fs.exists(repopath / ".mount") then
	if not vfs.open(repopath) then
		error(string.format("open repo failed, repo path : %s", repopath))
	end
else
	local mounts = {
		["engine"] = repopath,
		["engine/assets"] = repopath / "assets",
		[""] = repopath,
	}
	vfs.mount(mounts, repopath)
end

-- init local repo
local repo_cachepath = vfs.repopath()
if not fs.exists(repo_cachepath) then
	fs.create_directories(repo_cachepath)
end
for i=0,0xff do
	local abspath = repo_cachepath / string.format("%02x", i)
	fs.create_directories(abspath)
end
