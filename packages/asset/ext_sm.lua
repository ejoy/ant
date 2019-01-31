local rawtable = require "rawtable"
local assetmgr = require "asset"
return function (pkgname, respath)
	return rawtable(assetmgr.find_depiction_path(pkgname, respath))	
end