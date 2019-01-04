local rawtable = require "common.rawtable"
local assetmgr = require "asset"

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)
	return rawtable(fn)
end