local fu = require "filesystem.util"
local meshconverter = require "meshconverter"
local path = require "filesystem.path"
local modelutil = require "modelloader.util"
local lfs = require "lfs"
local config = modelutil.default_config()

local cvt = {}; cvt.__index = cvt

local convert_op = {
	bin = meshconverter.convert_BGFXBin,
	fbx = meshconverter.convert_FBX,
}

cvt.__call = function (srcpath)
	assert(path.is_absolute_path(srcpath))	
	local outputfile = path.replace_ext(srcpath, "antmesh")

	if fu.file_is_newer(srcpath, outputfile) then
		fu.create_dirs(path.parent(outputfile))

		local ext = path.ext(srcpath):lower()

		local convertor = convert_op[ext]
		if convertor == nil then
			return nil, string.format("not support convert mesh format : %s", ext)
		end
		convertor(srcpath, outputfile, config)
	end

	return outputfile
end

function cvt.build(plat, sourcefile, param, outfile)
	local t = param.sourcetype
	local c = convert_op[t]
	local cfg = param.config or config
	c(sourcefile, outfile, cfg)
	return lfs.exist(outfile)
end

return cvt