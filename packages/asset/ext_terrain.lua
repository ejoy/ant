local assetmgr = require "asset"
local terrain_module = require "terrain"
local fs = require "filesystem"
local declmgr = import_package "ant.render".declmgr

return function (filename)
	local terrain = assetmgr.get_depiction(filename)

	if terrain.declname == nil then
		terrain.declname = "p3|t20|t21|n3"
	end

	local heightmap = terrain.heightmap
	if heightmap then
		heightmap.path 	= fs.path(heightmap.ref_path):localpath():string()
	end
	terrain.handle = terrain_module.create(terrain, declmgr.get(terrain.declname).handle)
    return terrain
end
