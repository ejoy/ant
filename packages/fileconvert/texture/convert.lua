local lfs 	= require "filesystem.local"
local fs	= require "filesystem"
local util  = require "util"
local vfs	= require "vfs"

local toolpath = util.valid_tool_exe_path "texturec"

local function which_format(plat, param)
	local compress = param.compress
	if compress then
		-- TODO: some bug on texturec tool, format is not 4X4 and texture size is not multipe of 4/5/6/8, the tool will crash
		if plat == "ios" then
			return "ASTC4X4"
		end
		return compress[plat]
	end

	return param.format
end

local extensions = {
	direct3d11 	= "dds",
	direct3d12 	= "dds",
	metal 		= "ktx",
	vulkan 		= "ktx",
	opengl 		= "ktx",
}

local function outfile_extension(renderer)
	return extensions[renderer]
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
	add_option(commands, "-t", assert(which_format(plat, param)))
	add_option(commands, "-q", "fastest")

	if param.maxsize then
		add_option(commands, "--max", param.maxsize)
	end

	if param.normalmap then
		add_option(commands, "-n")
	end

	local colorspace = param.colorspace or "sRGB"
	if colorspace == "linear" then
		add_option(commands, "--linear")
	elseif colorspace == "HDR" then
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

return function (identity, sourcefile, outfile, localpath)
	local plat, platinfo, renderer = util.identify_info(identity)
	local ext = assert(outfile_extension(renderer))
	local tmpoutfile = lfs.path(outfile):replace_extension(ext)

	local commands = {
		toolpath:string(),
		stdout      = true,
		stderr      = true,
		hideWindow  = true,
	}

	local texcontent = util.rawtable(sourcefile)
	
	local texpath = localpath(assert(texcontent.path))

	gen_commands(plat, texcontent, texpath, tmpoutfile, commands)

	local success, msg = util.spawn_process(commands, function (info)
		local success, msg = true, ""
		if info ~= "" then
			local INFO = info:upper()
			success = INFO:find("ERROR:", 1, true) == nil
			msg = util.to_cmdline(commands) .. "\n" .. info .. "\n"
		end
		return success, msg
	end)

	if success then
		if lfs.exists(tmpoutfile) then
			util.embed_file(outfile, texcontent, {util.fetch_file_content(tmpoutfile)})
			lfs.remove(tmpoutfile)
			return success, msg
		end

		msg = msg .. "\nconvert texture return success, but not found file:" .. tmpoutfile:string()
	end

	return false, msg
end