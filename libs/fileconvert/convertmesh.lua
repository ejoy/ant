local fu = require "filesystem.util"
local meshconverter = require "meshconverter"
local path = require "filesystem.path"
local modelutil = require "modelloader.util"
local config = modelutil.default_config()

return function (srcpath)
	assert(path.is_absolute_path(srcpath))	
	local outputfile = path.replace_ext(srcpath, "antmesh")

	if fu.file_is_newer(srcpath, outputfile) then
		fu.create_dirs(path.parent(outputfile))

		local ext = path.ext(srcpath):lower()

		local convert_op = {
			bin = meshconverter.convert_BGFXBin,
			fbx = meshconverter.convert_FBX,
		}

		local convertor = convert_op[ext]
		if convertor == nil then
			return nil, string.format("not support convert mesh format : %s", ext)
		end
		convertor(srcpath, outputfile, config)
	end

	return outputfile
end