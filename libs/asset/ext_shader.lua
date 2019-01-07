local assetutil = require "util"
local assetmgr = require "asset"
local rawtable = require "asset.rawtable"

return function (filename)
	return assetutil.shader_loader(rawtable(assetmgr.find_depiction_path(filename)))
end
