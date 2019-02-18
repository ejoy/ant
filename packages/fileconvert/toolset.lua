local subprocess = require "subprocess"
local fs = require "filesystem"
local localfs = require "filesystem.local"
local platform = require "platform"
local OS = platform.OS

local function init_config()
	local enginedir = fs.path("engine"):localpath()
	local suffix = OS == "OSX" and "" or ".exe"

	local function to_execute_path(pathname)
		return enginedir / (pathname .. suffix)
	end

	local function valid_shaderc_path()
		for _, name in ipairs {
			"clibs/shadercDebug",
			"clibs/shadercRelease",
			"bin/shadercDebug",
			"bin/shadercRelease",
			"bin/shaderc",
		} do
			local exepath = to_execute_path(name)
			if localfs.exists(exepath) then
				return exepath
			end
		end

		error(string.format("not found any valid shaderc path. update bin folder or compile from 3rd/bgfx"))
	end

	return {
		lua = to_execute_path "bin/lua",
		shaderc = valid_shaderc_path(),
		shaderinc = enginedir / "3rd/bgfx/src",
	}
end

local toolset = {
	config = init_config()
}

local stage_types = {
	f = "fragment",
	v = "vertex",
	c = "compute",
}

local shader_options = {
	d3d9_v = "vs_3_0",
	d3d9_f = "ps_3_0",
	d3d11_v = "vs_4_0",
	d3d11_f = "ps_4_0",
	d3d11_c = "cs_5_0",
	glsl_v ="120",
	glsl_f ="120",
	glsl_c ="430",
	metal_v = "metal",
	metal_f = "metal",
	metal_c = "metal",
	vulkan_v = "spirv",
	vulkan_f = "spirv",
}

local function default_level(shadertype, stagetype)
	if shadertype:match("d3d") then
		return stagetype == "c" and 1 or 3
	end
end

function toolset.compile(filepath, outfilepath, shadertype, config)
	assert(localfs.exists(filepath), filepath:string())
	
	local shaderc = toolset.config.shaderc
	local srcfilename = filepath:string()
	local outfilename = outfilepath:string()

	local shaderinc_path = toolset.config.shaderinc

	if not localfs.exists(shaderinc_path) then
		error(string.format("bgfx shader include path is needed, \
							but path is not exist! path have been set : %s", config.shaderinc))
	end
	
	local includes = {}
	local function add_inc(includes, p)
		table.insert(includes, "-i")
		assert(p:is_absolute(), p:string())
		table.insert(includes, p:string())
	end

	add_inc(includes, shaderinc_path)

	if config.not_include_examples_common == nil then
		local incexamplepath = shaderinc_path:parent_path() / "examples/common"
		if not localfs.exists(incexamplepath) then
			error(string.format("example is needed, but not exist, path is : %s", incexamplepath))
		end

		add_inc(includes, incexamplepath)
	end

	if config.includes then
		for _, p in ipairs(config.includes) do
			if not localfs.exists(p) then
				error(string.format("include path : %s, but not exist!", p))
			end

			add_inc(includes, p)
		end
	end

	local st = config.stagetype or srcfilename:match "[/\\]([fvc])s_[^/\\]+.sc$"
	local shader_opt = config.shader_opt or assert(shader_options[shadertype .. "_" .. st], shadertype .. "_" .. st)

	local stagetype = stage_types[st]

	local commands = {
		shaderc:string(),
		"--platform", config.platform or OS,
		"--type", stagetype,
		"-p", shader_opt,
		"-f", srcfilename,
		"-o", outfilename,
		includes,
		stdout = true,
		stderr = true,
		hideWindow = true,
	}

	local function add_optimizelevel(level, defaultlevel)
		level = level or defaultlevel
		if level then
			table.insert(commands, "-O")
			table.insert(commands, tostring(level))
		end
	end

	add_optimizelevel(config.optimizelevel, default_level(shadertype, stagetype))

	local prog = subprocess.spawn(commands)

	local function to_cmdline()
		local s = ""
		for _, v in ipairs(commands) do
			if type(v) == "table" then
				for _, vv in ipairs(v) do
					s = s .. vv .. " "
				end
			else
				s = s .. v .. " "
			end
		end

		return s
	end
	print(to_cmdline())

	if not prog then
		return false, "Create shaderc process failed."
	else
		local function check_msg(info)
			local success, msg = true, ""
			if info ~= "" then
				local INFO = info:upper()
				success = INFO:find("ERROR:", 1, true) == nil
				msg = to_cmdline() .. "\n" .. info .. "\n"
			end

			return success, msg
		end

		local stds = {
			{fd=prog.stdout, info="[stdout info]:"},
			{fd=prog.stderr, info="[stderr info]:"}
		}

		local success, msg = true, ""
		while #stds > 0 do
			for idx, std in ipairs(stds) do
				local fd = std.fd
				local num = subprocess.peek(fd)
				if num == nil then
					local s, m = check_msg(std.info)
					success = success and s
					msg = msg .. "\n\n" .. m
					table.remove(stds, idx)
					break
				end

				if num ~= 0 then
					std.info = std.info .. fd:read(num)
				end
			end
		end

		return success, msg
	end
end

return toolset
