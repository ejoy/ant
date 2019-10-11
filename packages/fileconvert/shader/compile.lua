local toolset 	= require "shader.toolset"
local lfs 		= require "filesystem.local"
local util 		= require "util"

local engine_shader_srcpath = lfs.current_path() / "packages/resources/shaders"
local function check_compile_shader(plat, srcfilepath, outfilepath, shadertype, macros)	
	lfs.create_directories(outfilepath:parent_path())
	return toolset.compile(srcfilepath, outfilepath, shadertype, {
		includes = {engine_shader_srcpath},
		platform = plat,
		macros = macros,
	})
end

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

local function rawtable(filepath)
	local env = {}
	local r = assert(lfs.loadfile(filepath, "t", env))
	r()
	return env
end

local valid_shader_stage = {
	"vs", "fs", "cs"
}

return function (identity, srcfilepath, _, outfilepath)
	local plat, renderer = util.identify_info(identity)
	local shadertype = shadertypes[renderer:upper()]
	assert(plat)
	assert(shadertype)

	local fxcontent = rawtable(srcfilepath)
	local shader = assert(fxcontent.shader)
	local marcros = shader.macros

	local errors = {}
	local all_depends = {}
	local build_success = true
	
	for _, stagename in ipairs(valid_shader_stage)do
		local shader_srcpath = lfs.path(shader[stagename])
		local shader_binpath = lfs.path(shader_srcpath):replace_extension ".bin"

		local success, err, depends = check_compile_shader(plat, shader_binpath, shader_binpath, shadertype, marcros)
		build_success = build_success and success
		if err then
			errors[#errors+1] = err
		end

		if success then
			table.move(depends, 1, #depends, #all_depends+1, all_depends)
		end

		do
			local f = lfs.open(shader_binpath, "rb")
			local c = f:read "a"
			f:close()
			shader[stagename .. "bin"] = c
		end
	end

	if build_success then
		local utility = import_package "utility"
		local stringify = utility.stringify
		local s = stringify(c, false, true)
		local f = lfs.open(outfilepath, "wb")
		f:write(s):close()
	end
	return build_success, table.concat(errors, "\n"), all_depends
end
