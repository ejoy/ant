local log = log and log(...) or print

local mesh_loader = import_package "ant.modelloader".loader
local assetmgr = require "asset"
local fs = require "filesystem"

return function (filename)
	local mesh = assetmgr.get_depiction(filename)
	local meshpath =  fs.path(mesh.mesh_path)
	if fs.exists(meshpath) then
		mesh.handle = mesh_loader.load(meshpath)
	else
		log(string.format("load mesh path failed, mesh file:[%s], .mesh file:[%s],", meshpath, filename))
	end 
    return mesh
end
