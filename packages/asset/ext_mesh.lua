local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader"
local assetmgr = require "asset"
local pfs = require "filesystem.pkg"

return function (filename)
	local mesh = assetmgr.get_depiction(filename)
	local meshpath =  pfs.path(mesh.mesh_path)
	if pfs.exists(meshpath) then
		mesh.handle = mesh_loader.load(meshpath)
	else
		log(string.format("load mesh path failed, mesh file:[%s], .mesh file:[%s],", meshpath, filename))
	end 
    return mesh
end
