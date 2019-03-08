local assetmgr = require "asset"

return function(filename, param)
	local loader = assetmgr.get_loader("ozz")
	return loader(filename, param)
end