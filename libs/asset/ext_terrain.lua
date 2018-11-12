local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "rawtable"
local path = require "filesystem.path"

-- terrain loader protocal 
return function (filename, param)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then 
		error(string.format("invalid file in ext_terrain, %s", filename))
	end
	
    local mesh = rawtable(fn)
    -- todo: terrain struct 
    -- or use extension file format outside
     
    return mesh
end
