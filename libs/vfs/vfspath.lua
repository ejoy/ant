local fs = require "filesystem"
local enginepath = fs.absolute(fs.path(...))
local repopath = fs.current_path()

local mod_searchdirs = {
	["engine"] = enginepath,
}

local vfs = require "vfs"

if fs.exists(repopath / ".mount") then
	if not vfs.open(repopath) then
		error(string.format("open repo failed, repo path : %s", repopath))
	end
else
	local mounts = {
		["engine/assets"] = enginepath / "assets",
		[""] = repopath,
	}
	for name, path in pairs(mod_searchdirs) do
		mounts[name] = path
	end
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
