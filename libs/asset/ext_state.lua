local assetmgr = require "asset"
local rawtable = require "asset.rawtable"

return function (filename)
	return rawtable(assetmgr.find_depiction_path(filename))
end
