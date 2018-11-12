-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable" 
local vfs = require "vfs"

-- luacheck: ignore param
return function(filename, param)
	local content = rawtable(filename)

	local assetmgr = require "asset"
	

	local anifile = assetmgr.find_valid_asset_path(content.path .. ".ozz")

	if anifile == nil then
		error(string.format("file not found, filename : ", filename))
	end

	local animodule = require "hierarchy.animation"
	local rp_anifile = vfs.realpath(anifile)
	content.handle = animodule.new_ani(rp_anifile)
	return content
end