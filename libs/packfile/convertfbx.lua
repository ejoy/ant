local assetmgr = require "asset"
local path = require "filesystem.path"

local winfile = require "winfile"
local rawopen = winfile.open or io.open

local function gen_cache_path(srcpath)
	local outputfile = path.replace_ext(srcpath, "antmesh")
	return path.join("cache", outputfile)
end

return function(lk, readmode)
	local c = assetmgr.load(lk)
	local meshpath = c.mesh_src	
	assert(path.ext(meshpath) == "fbx")
	meshpath = assetmgr.find_valid_asset_path(meshpath)
	if meshpath == nil then
		print("not found file : ", meshpath)
	end

	local config = c.config
	local assimp = require "assimplua"
	
	local outputfile = gen_cache_path(meshpath)
	assimp.ConvertFBX(meshpath, outputfile, config)

	return rawopen(outputfile, readmode)
end