local toolset = require "shader.toolset"
local lfs = require "filesystem.local"
local util = require "util"

local engine_shader_srcpath = lfs.current_path() / "packages/resources/shaders/src"

local function compile_shader(plat, srcfilepath, outfilepath, shadertype)
	local config = {
		includes = {engine_shader_srcpath},
		platform = plat,
	}
	return toolset.compile(srcfilepath, outfilepath, shadertype, config)
end

local function check_compile_shader(plat, srcfilepath, outfilepath, shadertype)	
	lfs.create_directories(outfilepath:parent_path())
	return compile_shader(plat, srcfilepath, outfilepath, shadertype)
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

return function (identity, srcfilepath, _, outfilepath)	
	local plat, renderer = util.identify_info(identity)
	local shadertype = shadertypes[renderer:upper()]
	assert(plat)
	assert(shadertype)
	return check_compile_shader(plat, srcfilepath, outfilepath, shadertype)
end
