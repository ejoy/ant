-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable"
local assetutil = require "util"

return function (filename)
	return assetutil.shader_loader(rawtable(filename))
end

