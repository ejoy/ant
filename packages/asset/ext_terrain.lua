local assetmgr = require "asset"
local terrain_module = require "lterrain"
local declmgr = import_package "ant.render".declmgr

return function (filename)
	local terrain = assetmgr.get_depiction(filename)

	if terrain.declname == nil then
		terrain.declname = "p3|t20|t21|n3"
	end	

	local heightmap 			= terrain.heightmap
	terrain.heightmap_pkgpath 	= heightmap
	terrain.heightmap 	= heightmap:localpath():string()
	terrain.handle 		= terrain_module.create(terrain)
    return terrain
end
