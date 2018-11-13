local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "rawtable"
local path = require "filesystem.path"
local assetmgr = require "asset"

-- terrain loader protocal 
return function (filename, param)
	local fn = assetmgr.find_depiction_path(filename)	
	
    local mesh = rawtable(fn)
    -- todo: terrain struct 
    -- or use extension file format outside
     
    return mesh
end
