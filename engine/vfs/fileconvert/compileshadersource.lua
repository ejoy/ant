local toolset = require "vfs.fileconvert.toolset"
local lfs = require "filesystem.local"

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

return function (identity, srcfilepath, param, outfilepath)	
	local plat, shadertype = identity:match("([^-]+)-(.+)$")
	assert(plat)
	assert(shadertype)
	return check_compile_shader(plat, srcfilepath, outfilepath, shadertype)
end
