local convert_image = require "editor.texture.util"
local datalist 		= require "datalist"
local lfs 			= require "filesystem.local"
local depends 		= require "editor.depends"

local function which_format(os, param)
	local compress = param.compress
	if compress then
		if os == "ios" or os == "macos" then
			return "ASTC4x4"
		end
		return compress[os]
	end

	return param.format
end

local function readdatalist(filepath)
	local f = assert(lfs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data,function(args)
		return args[2]
	end)
end

return function (input, output, setting, localpath)
	local param = readdatalist(input)
	local depfiles = {}
	if param.path then
		param.setting = setting
		param.local_texpath = localpath(assert(param.path))
		param.format = which_format(setting.os, param)

		depends.add(depfiles, param.local_texpath)
	else
		assert(param.value, "memory texture should define the texture memory")
	
		if param.format ~= "RGBA8" then
			error(("memory texture only support format RGBA8, format:%s provided"):format(param.format))
		end
		
		local s = param.size
		local w,h = s[1], s[2]
		local numlayers = param.numLayers or 1
		if numlayers*w*h*4 ~= #param.value then
			error(("invalid image size [w, h]=[%d, %d], numLayers=%d, format:%s, value count:%d"):format(w, h, param.numLayers, param.format, #param.value))
		end
	end

	local ok, err = convert_image(output, param)
	if not ok then
		return ok, err
	end

	return true, depfiles
end
