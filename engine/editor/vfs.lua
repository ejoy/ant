local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
local repo = require "vfs.repo"

local self

function localvfs.realpath(pathname)
	local rp = access.realpath(self, pathname)
	local lk = lfs.path(rp:string() .. ".lk")
	if lfs.exists(lk) then
		local binhash = access.build_from_path(self, self.identity, pathname)
		if binhash == nil then
			error(string.format("build from path failed, pathname:%s, log file can found in log folder", pathname))
		end
		return access.repopath(self, binhash):string()
	end
	return rp:string(), pathname:match "^/?(.-)/?$"
end

function localvfs.list(path)
	path = path:match "^/?(.-)/?$"
	local files = access.list_files(self, path)
	path = path .. '/'
	local item = {}
	for filename in pairs(files) do
		local realpath = access.realpath(self, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	return item
end

function localvfs.type(filepath)
	local rp = access.realpath(self, filepath)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function localvfs.identity(identity)
	assert(self.identity == nil)
	self.identity = identity
end

function localvfs.new(path)
	self = repo.new(path)
end

package.loaded.vfs = localvfs
