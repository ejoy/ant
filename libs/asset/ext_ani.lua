-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "common.rawtable" 
local vfs = require "vfs"
local assetmgr = require "asset"
local path = require "filesystem.path"
local animodule = require "hierarchy.animation"

-- luacheck: ignore param
return function(filename, param)
	local fn = assetmgr.find_depiction_path(filename)
	local content = rawtable(fn)
	local srcpath = content.path
	assert(path.ext(srcpath) == nil)
	local anifile = assetmgr.find_valid_asset_path(srcpath .. ".ozz")

	if anifile == nil then
		error(string.format("invalid filename, %s : ", srcpath))
	end
	
	local rp_anifile = vfs.realpath(anifile)
	content.handle = animodule.new_ani(rp_anifile)
	return content
end