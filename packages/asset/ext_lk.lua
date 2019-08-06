local assetmgr = require "asset"

return {
	loader = function(filename)
		return assetmgr.get_depiction(filename)
	end
}
