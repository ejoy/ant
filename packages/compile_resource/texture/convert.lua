local samplerutil = import_package "ant.render".sampler
local stringify = import_package "ant.serialize".stringify
local subprocess = require "sp_util"
local datalist = require "datalist"
local lfs = require "filesystem.local"

local TEXTUREC = subprocess.tool_exe_path "texturec"

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

local function add_option(commands, name, value)
	if name then
		commands[#commands+1] = name
	end
	
	if value then
		commands[#commands+1] = value
	end
end

local function gen_commands(commands, param, input, output)
	add_option(commands, "-f", input:string())
	add_option(commands, "-o", output:string())
	add_option(commands, "-t", param.format)
	add_option(commands, "-q", "fastest")

	if param.maxsize then
		add_option(commands, "--max", param.maxsize)
	end

	if param.normalmap then
		add_option(commands, "-n")
	end

	param.colorspace = param.colorspace or "sRGB"
	if param.colorspace == "linear" then
		add_option(commands, "--linear")
	elseif param.colorspace == "HDR" then
		print("not support HDR format right now")
	end

	local mipmap = param.mipmap
	if mipmap then
		add_option(commands, "-m")
		if mipmap ~= 0 then
			add_option(commands, "--mipskip", tostring(mipmap))
		end
	end
end

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function default_sampler()
	return {
		U="WRAP",
		V="WRAP",
		W="WRAP",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="POINT",
	}
end

local function fill_default_sampler(sampler)
	local d = default_sampler()
	if sampler == nil then
		return d
	end

	for k, v in pairs(d) do
		if sampler[k] == nil then
			sampler[k] = v
		end
	end

	return sampler
end

local function readdatalist(filepath)
	local f = assert(lfs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

return function (input, output, identity, localpath)
	local os, renderer = identity:match "(%w+)_(%w+)"
	local ext = assert(extensions[renderer])
	local binfile = (output / "main.bin"):replace_extension(ext)

	local commands = {
		TEXTUREC,
	}

	local param = readdatalist(input)
	local texpath = localpath(assert(param.path))

	param.format = assert(which_format(os, param))
	gen_commands(commands, param, texpath, binfile)

	local success, msg = subprocess.spawn_process(commands)
	if success then
		if msg:upper():find("ERROR:", 1, true) then
			success = false
		end
	end
	if not success then
		return false, msg
	end
	assert(lfs.exists(binfile))
	local config = {
		name	= texpath:string(),
		sampler = fill_default_sampler(param.sampler),
		flag	= samplerutil.sampler_flag(param.sampler),
	}
	if param.colorspace == "sRGB" then
		config.flag = config.flag .. 'Sg'
	end
	writefile(output / "main.cfg", stringify(config))
	lfs.rename(binfile, output / "main.bin")
	return true
end
