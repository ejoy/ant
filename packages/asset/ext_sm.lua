local rawtable = require "rawtable"
local assetmgr = require "asset"
return function (filename)
	return rawtable(assetmgr.find_depiction_path(filename))	
end
