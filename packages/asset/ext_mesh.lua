local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader"
local assetmgr = require "asset"
local fs = require "filesystem"
local rawtable = require "rawtable"

return function (pkgname, respath)
	local mesh = rawtable(assetmgr.find_depiction_path(pkgname, respath))
	local meshpath = mesh.mesh_path
	local mpkgname, mrespath = meshpath[1], fs.path(meshpath[2])
    local realrespath = assetmgr.find_asset_path(mpkgname, mrespath)
	if realrespath then
		mesh.handle = mesh_loader.load(realrespath)
	else
		log(string.format("load mesh path failed, mesh file:[%s:%s], .mesh file:[%s:%s],", 
			mpkgname, mrespath, pkgname, respath))
	end 
    return mesh
end
