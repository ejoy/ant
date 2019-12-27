local assetmgr = require "asset"

return {
	loader = function(filename)
		return assetmgr.load_depiction(filename), 0
	end
}
