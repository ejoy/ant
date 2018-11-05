local assetmgr = require "asset"
local fs = require "filesystem"
local path = require "filesystem.path"
local fu = require "filesystem.util"
local vfs = require "vfs"
local vfsutil = require "vfs.util"

local winfile = require "winfile"
local rawopen = winfile.open or io.open

local function gen_cache_path(srcpath)
	local outputfile = path.replace_ext(srcpath, "antmesh")
	return path.join("cache", outputfile)
end

return function(lk, readmode)
	local rp_lk = fu.convert_to_mount_path(lk, "engine/assets")
	local c = assetmgr.load(rp_lk)
	local meshpath = assetmgr.find_valid_asset_path(c.mesh_src)
	if not vfsutil.exist(meshpath) then
		error(string.format("file not exist : %s", meshpath))
	end

	local config = c.config
	local assimp = require "assimplua"
	
	local outputfile = gen_cache_path(c.mesh_src)
	path.create_dirs(path.parent(outputfile))
	local ext = path.ext(meshpath):lower()
	local rp_meshpath = vfs.realpath(meshpath)
	if ext == "bin" then
		assimp.convert_BGFXBin(rp_meshpath, outputfile, config)
	elseif ext == "fbx" then
		assimp.convert_FBX(rp_meshpath, outputfile, config)
	elseif ext == "ozz" then
		assimp.convert_OZZ(rp_meshpath, outputfile, config)
	else
		error(string.format("not support convert mesh format : %s, filename is : %s", ext, meshpath))
	end

	return rawopen(outputfile, readmode)
end