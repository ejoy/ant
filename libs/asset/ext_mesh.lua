local log = log and log(...) or print

local mesh_loader = require "modelloader"
local assetmgr = require "asset"
local fs = require "filesystem"
local rawtable = require "asset.rawtable"

return function (filename)
	local mesh = rawtable(assetmgr.find_depiction_path(filename)	)
    
    local mesh_path = assetmgr.find_valid_asset_path(fs.path(mesh.mesh_path))
	if mesh_path then
		mesh.handle = mesh_loader.load(mesh_path)
	else
		log(string.format("load mesh path failed, %s, .mesh file:%s", mesh.mesh_path, filename))
	end 
    return mesh
end
