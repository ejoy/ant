local rawtable = require "common.rawtable"
local assetutil = require "util"
local assetmgr = require "asset"

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)
	return assetutil.shader_loader(rawtable(fn))
end

