-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable" 
local hiemodule = require "hierarchy"


-- luacheck: ignore param
return function (filename, param)
	local content = rawtable(filename)
	local assetmgr = require "asset"
	local skefile = assetmgr.find_valid_asset_path(content.path .. ".ozz")

	if skefile == nil then
		error(string.format("file not found, filename : ", content.path))
	end
	content.handle = hiemodule.build(skefile)
	return content
end