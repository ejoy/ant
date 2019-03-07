local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader"
local assetmgr = require "asset"
local fs = require "filesystem"
local pfs = require "filesystem.pkg"
local rawtable = require "rawtable"

return function (pkgname, respath)
	local mesh = rawtable(assetmgr.find_depiction_path(pkgname, respath))
	local meshpath = mesh.mesh_path
    local realrespath = assetmgr.find_asset_path(pfs.path(meshpath))
	if realrespath then
		mesh.handle = mesh_loader.load(realrespath)
	else
		log(string.format("load mesh path failed, mesh file:[%s:%s], .mesh file:[%s],", meshpath, pkgname, respath))
	end 
    return mesh
end
