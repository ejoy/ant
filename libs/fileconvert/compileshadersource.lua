local toolset = require "editor.toolset"
local fs = require "filesystem"
local vfs = require "vfs"

local function compile_shader(plat, filename, outfilename, shadertype)
    local config = toolset.load_config()
	if config.shaderc then		
		local engineshaderpath = vfs.realpath("engine/assets/shaders/src")
		config.includes = {config.shaderinc, engineshaderpath}
        config.dest = outfilename
		return toolset.compile(filename, config, shadertype, plat)
	end
	
	return nil, "config is empty, try run `lua tools/config.lua`"
end

local function check_compile_shader(plat, srcpath, outfile, shadertype)	
	fs.create_directories(outfile:parent())	
	return compile_shader(plat, srcpath, outfile, shadertype)
end

return function (identity, sourcefile, param, outfile)	
	local plat, shadertype = identity:match("([^-]+)-(.+)$")
	assert(plat)
	assert(shadertype)
	return check_compile_shader(plat, sourcefile, outfile, shadertype)
end
