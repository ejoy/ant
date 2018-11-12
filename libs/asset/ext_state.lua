local require = import and import(...) or require

local rawtable = require "rawtable"
local assetmgr = require "asset"

return function (filename)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then 
		error(string.format("invalid file in ext_state, %s", filename))
	end

	return rawtable(fn)
end