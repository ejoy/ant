local assetmgr = require "asset"

return {
	loader = assetmgr.get_loader "ozz",
	unloader = assetmgr.get_unloader "ozz",
}