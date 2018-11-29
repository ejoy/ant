local meshconverter = require "meshconverter"

local modelutil = require "modelloader.util"
local lfs = require "lfs"
local util = require "filesystem.util"
local config = modelutil.default_config()

local convert_op = {
	bin = meshconverter.convert_BGFXBin,
	fbx = meshconverter.convert_FBX,
}

return function (plat, sourcefile, param, outfile)
	local t = param.sourcetype
	local c = convert_op[t]
	local cfg = param.config or config
	c(sourcefile, outfile, cfg)
	return util.exist(outfile)
end