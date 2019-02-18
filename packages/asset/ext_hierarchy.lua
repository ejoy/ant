local assetmgr = require "asset"

return function(pkgname, filename, param)
	local loader = assetmgr.get_loader("ozz")
	return loader(pkgname, filename, param)
end