-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable" 
local hiemodule = require "hierarchy"
local vfs = require "vfs"
local assetmgr = require "asset"
local path = require "filesystem.path"

-- luacheck: ignore param
return function (filename, param)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then 
		error(string.format("invalid file in ext_ske, %s", filename))
	end
	local content = rawtable(fn)
	
	local srcpath = content.path
	assert(path.ext(srcpath) == nil)
	local skefile = assetmgr.find_valid_asset_path(srcpath .. ".ozz")

	if skefile == nil then
		error(string.format("invalid file, define in %s", srcpath))
	end
	local rp_skefile = vfs.realpath(skefile)
	content.handle = hiemodule.build(rp_skefile)
	return content
end