local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader"
local assetmgr = require "asset"
local fs = require "filesystem"
local rawtable = require "rawtable"

return function (pkgname, respath)
	local mesh = rawtable(assetmgr.find_depiction_path(pkgname, respath))
    local mesh_path = assetmgr.find_asset_path(mesh.pkgname, fs.path(mesh.mesh_path))
	if mesh_path then
		mesh.handle = mesh_loader.load(mesh_pkgname, mesh_path)
	else
		log(string.format("load mesh path failed, mesh file:[%s:%s], .mesh file:[%s:%s],", 
			mesh.mesh_path, mesh.pkgname or "engine", pkgname, respath))
	end 
    return mesh
end
