local subprocess= require "subprocess"
local lfs = require "filesystem.local"
local util      = require "util"
local toolname = util.valid_tool_exe_path "texturec"


local function which_format(plat, param)
	local compress = param.compress
	if compress then
		return compress[plat]
	end

	return param.format
end

return function (identity, sourcefile, param, outfile)
	local plat = util.identify_info(identity)
	local tmpoutfile = lfs.path(outfile):replace_extension "ktx"
	local commands = {
		toolname:string(),
		"-f", sourcefile:string(),
		"-o", tmpoutfile:string(),
		"-t", which_format(plat, param),
		stdout      = true,
		stderr      = true,
		hideWindow  = true,
	}

	local function add_option(name, value)
		commands[#commands+1] = name
		if value then
			commands[#commands+1] = value
		end
	end

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

	local mipmap = param.colorspace
	if mipmap then
		add_option("-m")
		if mipmap ~= 0 then
			add_option("--mipskip", mipmap)
		end
	end

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
		if lfs.exist(tmpoutfile) then
			local r, err = pcall(lfs.rename, tmpoutfile, outfile)
			if r then
				return success, msg
			end

			msg = msg  .. "\nrename file failed, from :" .. tmpoutfile:string() .. ", to :", outfile:string() .. ", error :", err)
		else
			msg = msg .. "\nconvert texture return success, but not found file:" .. tmpoutfile:string()
		end
	end

	return false, msg
end