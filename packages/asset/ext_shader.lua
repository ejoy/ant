local assetutil = require "util"
local assetmgr = require "asset"
local rawtable = require "rawtable"

return function (pkgname, respath)
	return assetutil.shader_loader(pkgname, rawtable(assetmgr.find_depiction_path(pkgname, respath)))
end
