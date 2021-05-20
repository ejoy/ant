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
	local id = ident_util.parse(setting.identity)
	local ext = assert(extensions[id.renderer])
	local binfile = (output / "main.bin"):replace_extension(ext)

	local param = readdatalist(input)

	local texpath = localpath(assert(param.path))
	param.format = assert(which_format(id.platform, param))

	local ok, err = texutil.convert_image(output, texpath, binfile, param)
	if not ok then
		return ok, err
	end
	return true, {input}
end
