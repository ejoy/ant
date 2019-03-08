local toolset = require "toolset"
local fs = require "filesystem.local"
local pfs = require "filesystem.pkg"

local engine_shader_srcpath = pfs.path("//ant.resources/shaders/src"):localpath()

local function compile_shader(plat, srcfilepath, outfilepath, shadertype)
	local config = {
		includes = {engine_shader_srcpath},
		platform = plat,
	}
	return toolset.compile(srcfilepath, outfilepath, shadertype, config)
end

local function check_compile_shader(plat, srcfilepath, outfilepath, shadertype)	
	fs.create_directories(outfilepath:parent_path())
	return compile_shader(plat, srcfilepath, outfilepath, shadertype)
end

return function (identity, srcfilepath, param, outfilepath)	
	local plat, shadertype = identity:match("([^-]+)-(.+)$")
	assert(plat)
	assert(shadertype)
	return check_compile_shader(plat, srcfilepath, outfilepath, shadertype)
end
