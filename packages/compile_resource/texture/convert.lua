local lfs 	= require "filesystem.local"

local ru = import_package "ant.render".util
local stringify = import_package "ant.serialize".stringify
local utilitypkg = import_package "ant.utility"
local subprocess = utilitypkg.subprocess
local fs_local = utilitypkg.fs_local

local toolpath = fs_local.valid_tool_exe_path "texturec"

local extensions = {
	DIRECT3D11 	= "dds",
	DIRECT3D12 	= "dds",
	METAL 		= "ktx",
	VULKAN 		= "ktx",
	OPENGL 		= "ktx",
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

local function gen_commands(plat, param, sourcefile, outfile, commands)
	add_option(commands, "-f", sourcefile:string())
	add_option(commands, "-o", outfile:string())
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

-- local function gen_compressor_commands(plat, param, sourcefile, outfile, commands)
-- 	local function add_format_option()
-- 		local format = which_format(plat, param)
-- 		if plat == "window" then
-- 			add_option(commands, "-fd", format)
-- 		else
-- 			local astc, block = format:match "ASTC[%d.%w]+"
-- 			add_option(commands, "-fd", astc)
-- 			add_option(commands, "-BlockRate", block)
-- 		end
-- 	end

-- 	local mipmap = param.mipmap
-- 	if mipmap then
-- 		if mipmap == 0 then
-- 			add_option(commands, "-mipsize", 1)	--mean generate all mipmap
-- 		else
-- 			add_option(commands, "-miplevels", mipmap)
-- 		end
-- 	end

-- 	add_format_option()
-- 	add_option(commands, nil, sourcefile:string())
-- 	add_option(commands, nil, outfile:string())
-- end

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function absolute_path(base, path, convert)
	if path:sub(1,1) == "/" then
		return convert(path)
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

return function (config, sourcefile, outpath, localpath)
	local ext = assert(extensions[config.renderer])
	local binfile = (outpath / "main.bin"):replace_extension(ext)

	local commands = {
		toolpath:string(),
		stdout      = true,
		stderr      = true,
		hideWindow  = true,
	}

	local param = fs_local.datalist(sourcefile)
	local texpath = absolute_path(sourcefile, assert(param.path), localpath)

	param.format = assert(which_format(config.os, param))
	gen_commands(config.os, param, texpath, binfile, commands)

	local success, msg = subprocess.spawn_process(commands, function (info)
		local success, msg = true, ""
		if info ~= "" then
			local INFO = info:upper()
			success = INFO:find("ERROR:", 1, true) == nil
			msg = subprocess.to_cmdline(commands) .. "\n" .. info .. "\n"
		end
		return success, msg
	end)

	if success then
		if lfs.exists(binfile) then
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
			return success, msg
		end

		msg = msg .. "\nconvert texture return success, but not found file:" .. binfile:string()
	end

	return false, msg
end
