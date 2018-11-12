-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable" 
local hiemodule = require "hierarchy"
local vfs = require "vfs"


-- luacheck: ignore param
return function (filename, param)
	local content = rawtable(filename)
	local assetmgr = require "asset"
	local skefile = assetmgr.find_valid_asset_path(content.path .. ".ozz")

	if skefile == nil then
		error(string.format("file not found, filename : ", content.path))
	end
	local rp_skefile = vfs.realpath(skefile)
	content.handle = hiemodule.build(rp_skefile)
	return content
end