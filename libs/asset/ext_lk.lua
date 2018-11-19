local require = import and import(...) or require

local rawtable = require "common.rawtable"
local assetmgr = require "asset"

return function(filename)
	return rawtable(assetmgr.find_depiction_path(filename))
end