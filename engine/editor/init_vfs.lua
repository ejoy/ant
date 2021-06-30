local vfs, rootpath = ...
local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

local function create_repo(path)
    path = lfs.path (path)
	if not lfs.is_directory(path) then
		return nil, "Not a dir"
	end
	local repo = {
		_root = path,
	}
	access.readmount(repo)
	return repo
end

local repo = assert(create_repo(rootpath))
vfs.repo = repo
function vfs.realpath(pathname)
	local rp = access.realpath(repo, pathname)
	if lfs.exists(rp) then
		return rp:string()
	end
end
