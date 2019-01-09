local toolset = require "fileconvert.toolset"
local fs = require "filesystem"
local vfs = require "vfs"

local function compile_shader(plat, srcfilepath, outfilepath, shadertype)
	local config = {
		includes = {fs.path(vfs.realpath("engine/assets/shaders/src"))},
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
