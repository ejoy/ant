local lfs = require "filesystem.local"
local subprocess = import_package "ant.subprocess"
local SHADERC = subprocess.tool_exe_path "shaderc"
local toolset = {}

local stage_types = {
	fs = "fragment",
	vs = "vertex",
	cs = "compute",
}

local shader_options = {
	direct3d9 = {
		vs = "vs_3_0",
		fs = "ps_3_0",
	},
	direct3d11 = {
		vs = "vs_5_0",
		fs = "ps_5_0",
		cs = "cs_5_0",
	},
	direct3d12 = {
		vs = "vs_5_0",
		fs = "ps_5_0",
		cs = "cs_5_0",
	},
	opengl = {
		vs = "120",
		fs = "120",
		cs = "430",
	},
	metal = {
		vs = "metal",
		fs = "metal",
		cs = "metal",
	},
	vulkan = {
		vs = "spirv",
		fs = "spirv",
	},
}

function toolset.compile(config)
	local commands = {
		SHADERC,
		"--platform", config.platform,
		"--type", stage_types[config.stage],
		"-p", shader_options[config.renderer][config.stage],
		"-f", config.input,
		"-o", config.output,
		"--depends",
	}

	if config.includes then
		for _, p in ipairs(config.includes) do
			if not lfs.exists(p) then
				error(string.format("include path : %s, but not exist!", p))
			end
			assert(p:is_absolute(), p:string())
			commands[#commands+1] = "-i"
			commands[#commands+1] = p:string()
		end
	end

	if config.macros then
		local t = {}
		for _, m in ipairs(config.macros) do
			t[#t+1] = m
		end
		if #t > 0 then
			local defines = table.concat(t, ';')
			commands[#commands+1] = "--define"
			commands[#commands+1] = defines
		end
	end

	local level = config.optimizelevel
	if not level then
		if config.renderer:match("direct3d") then
			level = config.stage == "cs" and 1 or 3
		end
	end

	if config.debug then
		commands[#commands+1] = "--debug"
	else
		if level then
			commands[#commands+1] = "-O"
			commands[#commands+1] = tostring(level)
		end
	end

	print("shader compile:")
	local cmdstring = {}
	for _, c in ipairs(commands) do
		cmdstring[#cmdstring+1] = tostring(c)
	end

	print(table.concat(cmdstring, " "))

	do
		-- Fixes bgfx shaderc bug
		lfs.remove(config.output)
		lfs.open(config.output, "wb"):close()
	end

	local ok, msg = subprocess.spawn_process(commands)
	if ok then
		local INFO = msg:upper()
		for _, term in ipairs {
			"ERROR",
			"FAILED TO BUILD SHADER"
		} do
			if INFO:find(term, 1, true) then
				ok = false
				break
			end
		end
	end
	if not ok then
		return false, msg
	end
	local depends = {}
	local dependpath = config.output .. ".d"
	local f = lfs.open(dependpath)
	if f then
		f:read "l"
		for line in f:lines() do
			local path = line:match "^%s*(.-)%s*\\?$"
			if path then
				depends[#depends+1] = path
			end
		end
		f:close()
		os.remove(dependpath:string())
		table.sort(depends)
		table.insert(depends, 1, config.input)
	end
	return true, msg, depends
end

return toolset
