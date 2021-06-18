local texutil = require "editor.texture.util"
local datalist = require "datalist"
local lfs = require "filesystem.local"
local ident_util = require "identity"

local extensions = {
	direct3d11 	= "dds",
	direct3d12 	= "dds",
	metal 		= "ktx",
	vulkan 		= "ktx",
	opengl 		= "ktx",
}

local function which_format(plat, param)
	local compress = param.compress
	if compress then
		-- TODO: some bug on texturec tool, format is not 4X4 and texture size is not multipe of 4/5/6/8, the tool will crash
		if plat == "ios" or plat == "osx" then
			return "ASTC4X4"
		end
		return compress[plat]
	end

	return param.format
end

local function readdatalist(filepath)
	local f = assert(lfs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

return function (input, output, setting, localpath)
	local param = readdatalist(input)
	param.name = input:string()
	local dependfiles = {input}
	if param.path then
		local id = ident_util.parse(setting.identity)
		param.binfile = texutil.what_bin_file(output, id)
		param.local_texpath = localpath(assert(param.path))
		param.format = assert(which_format(id.platform, param))

		dependfiles[#dependfiles+1] = param.path
	else
		assert(param.value, "memory texture should define the texture memory")
	
		if param.format ~= "RGBA8" then
			error(("memory texture only support format RGBA8"))
		end
		
		local s = param.size
		local w,h = s[1], s[2]
		if w*h*4 ~= #param.value then
			error(("invalid image size [w, h]=[%d, %d], format:%s, value count:%d"):format(w, h, param.format, #param.value))
		end
	end

	local ok, err = texutil.convert_image(output, param)
	if not ok then
		return ok, err
	end

	return true, dependfiles
end
