local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader"
local assetmgr = require "asset"
local pfs = require "filesystem.pkg"
local rawtable = require "rawtable"

return function (filename)
	local mesh = rawtable(assetmgr.find_depiction_path(filename))
	local meshpath = mesh.mesh_path
    local realrespath = assetmgr.find_asset_path(pfs.path(meshpath))
	if realrespath then
		mesh.handle = mesh_loader.load(realrespath)
	else
		log(string.format("load mesh path failed, mesh file:[%s], .mesh file:[%s],", meshpath, filename))
	end 
    return mesh
end
