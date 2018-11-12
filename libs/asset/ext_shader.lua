-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable"
local assetutil = require "util"
local assetmgr = require "asset"

return function (filename)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then 
		error(string.format("invalid file in ext_ske, %s", filename))
	end
	
	return assetutil.shader_loader(rawtable(fn))
end

