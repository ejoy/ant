local assetmgr = require "asset"
local rawtable = require "rawtable"

return function (pkgname, respath)
	return rawtable(assetmgr.find_depiction_path(pkgname, respath))
end
