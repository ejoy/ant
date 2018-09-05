local assetmgr = require "asset"
local fs = require "filesystem"
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
	meshpath = path.join(assetmgr.assetdir(), meshpath)
	if not fs.exist(meshpath) then
		print("file not exist : ", meshpath)
	end

	local config = c.config
	local assimp = require "assimplua"
	
	local outputfile = gen_cache_path(c.mesh_src)
	path.create_dirs(path.parent(outputfile))
	local ext = path.ext(meshpath):lower()
	if ext == "bin" then
		assimp.convert_BGFXBin(meshpath, outputfile, config)
	elseif ext == "fbx" then
		assimp.convert_FBX(meshpath, outputfile, config)
	else
		error(string.format("not support convert mesh format : %s, filename is : %s", ext, meshpath))
	end

	return rawopen(outputfile, readmode)
end