local log = log and log(...) or print

local rawtable = require "common.rawtable"
local mesh_loader = require "modelloader"
local assetmgr = require "asset"
local fs = require "filesystem"

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)	
	local mesh = rawtable(fn)
    
    local mesh_path = assetmgr.find_valid_asset_path(fs.path(mesh.mesh_path))
	if mesh_path then
		mesh.handle = mesh_loader.load(mesh_path)
	else
		log(string.format("load mesh path failed, %s, .mesh file:%s", mesh.mesh_path, filename))
	end 
    return mesh
end
