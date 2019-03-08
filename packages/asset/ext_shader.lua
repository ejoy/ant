local assetutil = require "util"
local assetmgr = require "asset"

return function (filename)
	return assetutil.shader_loader(assetmgr.get_depiction(filename))
end
