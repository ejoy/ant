local assetmgr = require "asset"

return function(filename)
	return assetmgr.get_depiction(filename)
end
