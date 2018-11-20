local fu = require "filesystem.util"
local modelutil = require "modelloader.util"
local assimp = require "assimplua"
local path = require "filesystem.path"

return function (srcpath)
	assert(path.is_absolute_path(srcpath))	
	local outputfile = path.replace_ext(srcpath, "antmesh")

	if fu.file_is_newer(srcpath, outputfile) then
		local lk_path = path.replace_ext(srcpath, "lk")
		local fs = require "lfs"
		local config
		if fs.exist(lk_path) then
			local rawtable = require "asset.common.rawtable"
			local c = rawtable(lk_path)
			config = c.config
		else
			config = modelutil.default_config()
		end

		path.create_dirs(path.parent(outputfile))

		local ext = path.ext(srcpath):lower()

		local convert_op = {
			bin = assimp.convert_BGFXBin,
			fbx = assimp.convert_FBX,
		}

		local convertor = convert_op[ext]
		if convertor == nil then
			return nil, string.format("not support convert mesh format : %s", ext)
		end
	end

	return outputfile
end