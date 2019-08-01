local lfs = require "filesystem.local"
local util      = require "util"

local toolname = "texturec"
local toolpath = util.valid_tool_exe_path(toolname)

local function which_format(plat, param)
	local compress = param.compress
	if compress then
		return compress[plat:lower()]
	end

	return param.format
end

local extensions = {
	d3d11 = "dds",
	d3d12 = "dds",
	metal = "ktx",
	vulkan = "ktx",
}

local function outfile_extension(renderer)
	return extensions[renderer:lower()]
end

local function add_option(commands, name, value)
	commands[#commands+1] = name
	if value then
		commands[#commands+1] = value
	end
end

local function gen_arm_astc_commands(plat, param, sourcefile, outfile, commands)
	add_option(commands, "-f", sourcefile:string())
	add_option(commands, "-o", outfile:string())
	add_option(commands, "-t", which_format(plat, param))

	if param.maxsize then
		add_option("--max", param.maxsize)
	end

	if param.normalmap then
		add_option("-n")
	end

	local colorspace = param.colorspace or "sRGB"
	if colorspace == "linear" then
		add_option("--linear")
	elseif colorspace == "HDR" then
		print("not support HDR format right now")
	end

	local mipmap = param.mipmap
	if mipmap then
		add_option("-m")
		if mipmap ~= 0 then
			add_option("--mipskip", mipmap)
		end
	end
end

return function (identity, sourcefile, param, outfile)
	local plat, renderer = util.identify_info(identity)
	local ext = assert(outfile_extension(renderer))
	local tmpoutfile = lfs.path(outfile):replace_extension(ext)
	
	local commands = {
		toolpath:string(),
		stdout      = true,
		stderr      = true,
		hideWindow  = true,
	}

	gen_arm_astc_commands(plat, param, sourcefile, tmpoutfile, commands)

	local success, msg = util.spaw_process(commands, function (info)
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
			local r, err = pcall(lfs.rename, tmpoutfile, outfile)
			if r then
				return success, msg
			end

			msg = msg  .. "\nrename file failed, from :" .. tmpoutfile:string() .. ", to :", outfile:string() .. ", error :" .. err
		else
			msg = msg .. "\nconvert texture return success, but not found file:" .. tmpoutfile:string()
		end
	end

	return false, msg
end