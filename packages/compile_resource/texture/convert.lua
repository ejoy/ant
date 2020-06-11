local lfs 	= require "filesystem.local"

local ru = import_package "ant.render".util
local stringify = import_package "ant.serialize".stringify
local utilitypkg = import_package "ant.utility"
local subprocess = utilitypkg.subprocess
local fs_local = utilitypkg.fs_local

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

return function (sourcefile, outpath, identity, localpath)
	local os, renderer = identity:match "(%w+)_(%w+)"
	local ext = assert(extensions[renderer])
	local binfile = (outpath / "main.bin"):replace_extension(ext)

	local commands = {
		TEXTUREC,
	}

	local param = fs_local.datalist(sourcefile)
	local texpath = localpath(assert(param.path))

	param.format = assert(which_format(os, param))
	gen_commands(commands, param, texpath, binfile)

	local success, msg = subprocess.spawn_process(commands)
	if success then
		if msg:upper():find("ERROR:", 1, true) then
			success = false
		end
	end
	if success then
		assert(lfs.exists(binfile))
		local config = {
			name = texpath:string(),
			sampler = ru.fill_default_sampler(param.sampler),
			flag = ru.generate_sampler_flag(param.sampler),
		}
		if param.colorspace == "sRGB" then
			config.flag = config.flag .. 'Sg'
		end
		writefile(outpath / "main.cfg", stringify(config))
		lfs.rename(binfile, outpath / "main.bin")
	end
	return success, msg
end
