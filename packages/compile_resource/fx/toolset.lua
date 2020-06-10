local lfs = require "filesystem.local"
local subprocess = import_package "ant.utility".subprocess

local SHADERC = subprocess.tool_exe_path "shaderc"
local toolset = {}

local shadertypes = {
	NOOP       = "d3d9",
	DIRECT3D9  = "d3d9",
	DIRECT3D11 = "d3d11",
	DIRECT3D12 = "d3d11",
	GNM        = "pssl",
	METAL      = "metal",
	OPENGL     = "glsl",
	OPENGLES   = "essl",
	VULKAN     = "spirv",
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
	spirv_v = "spirv",
	spirv_f = "spirv",
}

local function default_level(shadertype, stagetype)
	if shadertype:match("d3d") then
		return stagetype == "c" and 1 or 3
	end
end

function toolset.compile(config)
	local shadertype = shadertypes[config.renderer]

	local filepath 		= config.srcfile
	local outfilepath 	= config.outfile

	lfs.create_directories(outfilepath:parent_path())
	assert(lfs.exists(filepath), filepath:string())
	
	local srcfilename = filepath:string()
	local outfilename = outfilepath:string()

	local includes = {}
	local function add_inc(includes, p)
		table.insert(includes, "-i")
		assert(p:is_absolute(), p:string())
		table.insert(includes, p:string())
	end

	if config.includes then
		for _, p in ipairs(config.includes) do
			if not lfs.exists(p) then
				error(string.format("include path : %s, but not exist!", p))
			end

			add_inc(includes, p)
		end
	end

	local st = config.stagetype or srcfilename:match "([fvc])s[%w_]*%.sc$"
	local shader_opt = config.shader_opt or assert(shader_options[shadertype .. "_" .. st], shadertype .. "_" .. st)

	local stagetype = stage_types[st]

	local commands = {
		SHADERC,
		"--platform", assert(config.os),
		"--type", stagetype,
		"-p", shader_opt,
		"-f", srcfilename,
		"-o", outfilename,
		"--depends",
		includes,
	}

	local function add_defines(macros)
		if macros then
			local t = {}
			for _, m in ipairs(macros) do
				t[#t+1] = m
			end
			if next(t) then
				local defines = table.concat(t, ';')
				commands[#commands+1] = "--define"
				commands[#commands+1] = defines
			end
		end
	end

	add_defines(config.macros)

	local function add_optimizelevel(level, defaultlevel)
		level = level or defaultlevel
		if level then
			commands[#commands+1] = "-O"
			commands[#commands+1] = tostring(level)
		end
	end

	add_optimizelevel(config.optimizelevel, default_level(shadertype, stagetype))

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
	local dependpath = outfilepath .. ".d"
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

		depends[#depends+1] = filepath:string()
	end
	return true, msg, depends
end

return toolset
