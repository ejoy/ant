local assetmgr = require "asset"

return {
	loader = function(filename)
		return assetmgr.load_depiction(filename)
	end
}
