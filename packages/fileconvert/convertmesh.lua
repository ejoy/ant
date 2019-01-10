local meshconverter = require "meshconverter"
local fs = require "filesystem"
local modelutil = (import_package "ant.modelloader").util
local config = modelutil.default_config()

local convert_op = {
	bin = meshconverter.convert_BGFXBin,
	fbx = meshconverter.convert_FBX,
}

return function (identity, sourcefile, param, outfile)
	local t = param.sourcetype
	local c = convert_op[t]
	local cfg = param.config or config
	c(sourcefile, outfile, cfg)
	return fs.exists(outfile)
end