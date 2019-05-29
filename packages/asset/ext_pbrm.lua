local assetmgr = require "asset"
return function (filepath)
	return assetmgr.get_depiction_path(filepath)
end